use aiken/builtin
use aiken/cbor
use aiken/collection/list
use aiken/collection/pairs
use aiken/crypto.{sha2_256}
use aiken/interval.{Finite}
use aiken/primitive/bytearray.{length}
use aiken/primitive/string
use cardano/address.{Credential, Script}
use cardano/assets.{
  from_asset, from_lovelace, lovelace_of, merge, negate, quantity_of,
}
use cardano/certificate.{
  Certificate, DelegateBlockProduction, DelegateCredential,
}
use cardano/transaction.{OutputReference, Transaction, find_input}

pub type Redeemer {
  Send {
    signature: ByteArray,
    utxo: OutputReference,
    policy: ByteArray,
    assetname: ByteArray,
    amount: Int,
    pubkey: ByteArray,
    stakekey: ByteArray,
  }
  Merge
  Stake { signature: ByteArray, deadline: Int }
}

const magic =
  @"Bitcoin Signed Message:\n"

validator btc(pubKey: ByteArray) {
  spend(
    _datum: Option<Data>,
    redeemer: Redeemer,
    own_ref: OutputReference,
    self: Transaction,
  ) {
    //we'll build the message like this,txid+index+unit+amount+pubkey+stakekeys

    when redeemer is {
      Send(signature, utxo, policy, assetname, amount, pubkey, stakekey) -> {
        let message_array: List<ByteArray> =
          list.push([], stakekey)
            |> list.push(pubkey)
            |> list.push(bytearray.from_int_big_endian(amount, 20))
            |> list.push(assetname)
            |> list.push(policy)
            |> list.push(bytearray.from_int_big_endian(utxo.output_index, 1))
            |> list.push(utxo.transaction_id)

        let concat_array = concat_array(message_array)
        let message_hash = get_hash_from_bytearray(concat_array)

        //TODO da checkare
        //verify I am sending the right amount to the right user from the data i have in the first output
        //verify the second output goes to the starting one - the amount it had - 1 ADA
        let sending_value = from_asset(policy, assetname, amount)

        expect Some(contract_input) = find_input(self.inputs, own_ref)
        expect Some(payment_output) = list.at(self.outputs, 0)
        expect Some(returning_output) = list.at(self.outputs, 1)

        let starting_ada = lovelace_of(contract_input.output.value)

        let basic_validation = and {
            own_ref == utxo,
            validate_signature_key(pubKey, message_hash, signature),
          }

        if starting_ada > 4000000 {
          and {
            quantity_of(payment_output.value, policy, assetname) == quantity_of(
              sending_value,
              policy,
              assetname,
            ),
            merge(
              merge(contract_input.output.value, negate(sending_value)),
              negate(from_lovelace(1000000)),
            ) == returning_output.value,
            basic_validation,
          }
        } else {
          and {
            quantity_of(payment_output.value, policy, assetname) == quantity_of(
              sending_value,
              policy,
              assetname,
            ),
            merge(contract_input.output.value, negate(sending_value)) == returning_output.value,
            basic_validation,
          }
        }
      }
      //idealmente qua calcolo il valore totale in input e mi assicuro al contratto vada esattamente quell'ammontare - 2 ADA
      Merge -> False
      _ -> False
    }
  }

  //anyone can withdraw stake rewards, but only the user can do get them
  withdraw(_redeemer: Redeemer, account: Credential, self: Transaction) {
    when account is {
      Script(hash) -> {
        expect Some(withdrawAmount) = pairs.get_first(self.withdrawals, account)
        expect Some(first_output) = list.at(self.outputs, 0)
        and {
          first_output.value == from_lovelace(withdrawAmount - 1000000),
          first_output.address.payment_credential == Script(hash),
          withdrawAmount > 10000000,
        }
      }

      _ -> False
    }
  }

  publish(redeemer: Redeemer, certificate: Certificate, self: Transaction) {
    expect Stake(signature, deadline) = redeemer
    when certificate is {
      DelegateCredential(_, delegateCredential) -> {
        expect DelegateBlockProduction(poolId) = delegateCredential
        let message_hash = get_hash_from_bytearray(poolId)
        //TODO missing end in the hash
        trace cbor.diagnostic(message_hash)
        and {
          validate_signature_key(pubKey, message_hash, signature),
          validate_tx_end(self, deadline),
        }
      }
      _ -> {
        trace @"finisco qua"
        False
      }
    }
  }

  else(_) {
    fail
  }
}

fn get_hash_from_bytearray(byte: ByteArray) {
  //this is what I sign
  let concat_message =
    string.to_bytearray(bytearray.to_hex(sha2_256(sha2_256(byte))))
  let size = length(concat_message)

  //il doppio sha poi lo rendo stringa e maiuscolo, è quello che firmo
  let final_message =
    bytearray.concat(bytearray.from_int_big_endian(size, 1), concat_message)

  let magic_array = bytearray.from_string(magic)
  let final_magic = bytearray.concat(#"18", magic_array)

  let finalized = bytearray.concat(final_magic, final_message)

  sha2_256(sha2_256(finalized))
}

fn validate_signature_key(publicKey: ByteArray, msg: ByteArray, sig: ByteArray) {
  trace cbor.diagnostic(
    builtin.verify_ecdsa_secp256k1_signature(publicKey, msg, sig),
  )
  builtin.verify_ecdsa_secp256k1_signature(publicKey, msg, sig)
}

fn concat_array(list_array: List<ByteArray>) {
  list.reduce(list_array, #[], bytearray.concat)
}

fn validate_tx_end(tx: Transaction, deadline: Int) {
  trace cbor.diagnostic(deadline)
  when tx.validity_range.upper_bound.bound_type is {
    Finite(end) -> end < deadline
    _ -> False
  }
}
