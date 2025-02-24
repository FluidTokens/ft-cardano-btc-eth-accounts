use aiken/builtin
use aiken/cbor
use aiken/collection/list
use aiken/collection/pairs
use aiken/crypto.{keccak_256, sha2_256}
use aiken/interval.{Finite}
use aiken/option.{is_some}
use aiken/primitive/bytearray.{length}
use aiken/primitive/int.{to_string}
use aiken/primitive/string
use cardano/address.{
  Address, Credential, Script, from_script, from_verification_key,
  with_delegation_key, with_delegation_script,
}
use cardano/assets.{from_asset, from_lovelace, merge, negate, quantity_of, zero}
use cardano/certificate.{
  Certificate, DelegateBlockProduction, DelegateCredential,
}
use cardano/transaction.{
  Datum, InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
  find_input,
}
use constants
use redeemer.{Merge, Redeemer, Send, Stake}

validator global(pubKey: ByteArray) {
  spend(
    _datum: Option<Data>,
    redeemer: Redeemer,
    own_ref: OutputReference,
    self: Transaction,
  ) {
    //we'll build the message like this,txid+index+unit+amount+pubkey+stakekeys

    when redeemer is {
      Send(
        signature,
        utxos,
        policy,
        assetname,
        amount,
        policyInput,
        assetnameInput,
        amountInput,
        spendingscriptflag,
        pubkey,
        stakingscriptflag,
        stakekey,
        datumflag,
        datum,
        payment_index,
        fee,
        signer,
      ) -> {
        let list_utxos =
          list.foldr(
            utxos,
            [],
            fn(utxo, xs) {
              [
                utxo.transaction_id,
                bytearray.from_int_big_endian(utxo.output_index, 1),
                ..xs
              ]
            },
          )
        expect datum_converted: ByteArray = datum
        let message_array: List<ByteArray> =
          list.push([], bytearray.from_int_big_endian(fee, 20))
            |> list.push(bytearray.from_int_big_endian(payment_index, 1))
            |> list.push(datum_converted)
            |> list.push(bytearray.from_int_big_endian(datumflag, 1))
            |> list.push(stakekey)
            |> list.push(bytearray.from_int_big_endian(stakingscriptflag, 1))
            |> list.push(pubkey)
            |> list.push(bytearray.from_int_big_endian(spendingscriptflag, 1))
            |> list.push(bytearray.from_int_big_endian(amountInput, 20))
            |> list.push(assetnameInput)
            |> list.push(policyInput)
            |> list.push(bytearray.from_int_big_endian(amount, 20))
            |> list.push(assetname)
            |> list.push(policy)

        let concat_array = concat_array(list.concat(list_utxos, message_array))
        let message_hash_btc = get_hash_from_bytearray_btc(concat_array)
        let message_hash_eth = get_hash_from_bytearray_eth(concat_array)
        //TODO da checkare
        //verify I am sending the right amount to the right user from the data i have in the first output
        //verify the second output goes to the starting one - the amount it had - 1 ADA
        //address validation receiver is missing
        let sending_value = from_asset(policy, assetname, amount)
        let incoming_value =
          if amountInput > 0 {
            from_asset(policy, assetname, amount)
          } else {
            zero
          }

        expect Some(contract_input) = find_input(self.inputs, own_ref)
        expect Some(payment_output) = list.at(self.outputs, payment_index)

        let starting_value =
          find_inputs_value(self.inputs, contract_input.output.address)
        let final_value =
          find_outputs_value(self.outputs, contract_input.output.address)

        let flag_utxo_present = list.has(utxos, own_ref)

        let basic_validation = and {
            flag_utxo_present,
            or {
              validate_signature_key(pubKey, message_hash_btc, signature),
              validate_signature_key(pubKey, message_hash_eth, signature),
            },
          }
        //Check 1) The output is sending the right amount
        //Check 2) It is returning the right amount
        //Check 3) Is the right receiver
        //Check 4) Has the datum?
        //Check 5) Are all inputs in utxos present? This is important otherwise I could cancel something random
        //Check 6) Inputs that were not willing to be inside are from the same address and is a user
        //7)Issue now is the expected value coming, this is something we want to sign also? Add input value signed and we are done
        //Let's limit the max amount of outputs to the same wallet, otherwise someone could split all my ada in so many utxos making hard to spend them
        let expected_datum = calculate_datum(datumflag, datum)
        let expected_address =
          calculate_address(
            spendingscriptflag,
            stakingscriptflag,
            pubkey,
            stakekey,
          )
        and {
          quantity_of(payment_output.value, policy, assetname) == quantity_of(
            sending_value,
            policy,
            assetname,
          ),
          assets.match(
            final_value,
            merge(
              merge(
                merge(starting_value, negate(sending_value)),
                incoming_value,
              ),
              negate(from_lovelace(fee)),
            ),
            >=,
          ),
          basic_validation,
          payment_output.address == expected_address,
          payment_output.datum == expected_datum,
          all_inputs_present(utxos, self.inputs),
          only_external_signer_inputs_extra(utxos, self.inputs, signer),
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
          first_output.address == (
            from_script(hash) |> with_delegation_script(hash)
          ),
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
        let message_array: List<ByteArray> =
          list.push([], poolId)
            |> list.push(bytearray.from_int_big_endian(deadline, 20))
        let concat_message = concat_array(message_array)
        let message_hash_btc = get_hash_from_bytearray_btc(concat_message)
        let message_hash_eth = get_hash_from_bytearray_eth(concat_message)
        //let message_hash = get_hash_from_bytearray(poolId)
        //TODO missing end in the hash
        and {
          or {
            validate_signature_key(pubKey, message_hash_btc, signature),
            validate_signature_key(pubKey, message_hash_eth, signature),
          },
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

fn get_hash_from_bytearray_btc(byte: ByteArray) {
  //this is what I sign
  let concat_message =
    string.to_bytearray(bytearray.to_hex(sha2_256(sha2_256(byte))))
  let size = length(concat_message)

  //il doppio sha poi lo rendo stringa e maiuscolo, è quello che firmo
  let final_message =
    bytearray.concat(bytearray.from_int_big_endian(size, 1), concat_message)

  let magic_array = bytearray.from_string(constants.magic_btc)
  let final_magic = bytearray.concat(#"18", magic_array)

  let finalized = bytearray.concat(final_magic, final_message)

  sha2_256(sha2_256(finalized))
}

fn get_hash_from_bytearray_eth(byte: ByteArray) {
  //this is what I sign
  let concat_message =
    string.to_bytearray(bytearray.to_hex(sha2_256(sha2_256(byte))))
  let size = string.to_bytearray(to_string(length(concat_message)))

  //il doppio sha poi lo rendo stringa e maiuscolo, è quello che firmo
  let final_message = bytearray.concat(size, concat_message)

  let magic_array = bytearray.from_string(constants.magic_eth)
  let final_magic = bytearray.concat(#"19", magic_array)

  let finalized = bytearray.concat(final_magic, final_message)

  keccak_256(finalized)
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

fn find_inputs_value(inputs: List<Input>, sc_address: Address) {
  list.foldl(
    inputs,
    zero,
    fn(input, total) {
      if input.output.address == sc_address {
        merge(input.output.value, total)
      } else {
        total
      }
    },
  )
}

fn find_outputs_value(outputs: List<Output>, sc_address: Address) {
  list.foldl(
    outputs,
    zero,
    fn(output, total) {
      if output.address == sc_address {
        merge(output.value, total)
      } else {
        total
      }
    },
  )
}

pub fn calculate_address(
  flag_spending_script: Int,
  flag_staking_script: Int,
  pubkey: ByteArray,
  stakekey: ByteArray,
) -> Address {
  if flag_spending_script == 0 && flag_staking_script == 0 {
    from_verification_key(pubkey) |> with_delegation_key(stakekey)
  } else {
    if flag_spending_script == 0 && flag_staking_script == 1 {
      from_verification_key(pubkey) |> with_delegation_script(stakekey)
    } else {
      if flag_spending_script == 1 && flag_staking_script == 0 {
        from_script(pubkey) |> with_delegation_key(stakekey)
      } else {
        if flag_spending_script == 1 && flag_staking_script == 1 {
          from_script(pubkey) |> with_delegation_script(stakekey)
        } else {
          from_verification_key(pubkey) |> with_delegation_key(stakekey)
        }
      }
    }
  }
}

pub fn calculate_datum(flag_datum: Int, datum: Data) -> Datum {
  if flag_datum == 0 {
    NoDatum
  } else {
    InlineDatum(datum)
  }
}

pub fn all_inputs_present(
  utxos_chosen: List<OutputReference>,
  real_utxos: List<Input>,
) {
  list.all(utxos_chosen, fn(input) { is_some(find_input(real_utxos, input)) })
}

pub fn only_external_signer_inputs_extra(
  utxos_chosen: List<OutputReference>,
  real_utxos: List<Input>,
  address_signer: Address,
) {
  let list_external =
    list.filter(
      real_utxos,
      fn(input) { !list.has(utxos_chosen, input.output_reference) },
    )
  list.all(list_external, fn(input) { input.output.address == address_signer })
}
