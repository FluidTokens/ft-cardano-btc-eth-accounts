use aiken/builtin
use aiken/collection/list
use aiken/crypto.{keccak_256, sha2_256}
use aiken/primitive/bytearray
use cardano/transaction.{OutputReference, Transaction}

pub type Redeemer {
  signature: ByteArray,
  utxo: OutputReference,
  policy: ByteArray,
  assetname: ByteArray,
  amount: Int,
  pubkey: ByteArray,
  stakekey: ByteArray,
}

const magic =
  @"Ethereum Signed Message:\n"

validator eth(pubKey: ByteArray) {
  spend(
    _datum: Option<Data>,
    redeemer: Redeemer,
    own_ref: OutputReference,
    _self: Transaction,
  ) {
    //we'll build the message like this,txid+index+unit+amount+pubkey+stakekeys

    let message_array: List<ByteArray> =
      list.push([], redeemer.stakekey)
        |> list.push(redeemer.pubkey)
        |> list.push(redeemer.pubkey)
        |> list.push(bytearray.from_int_big_endian(redeemer.amount, 20))
        |> list.push(redeemer.assetname)
        |> list.push(redeemer.policy)
        |> list.push(bytearray.from_int_big_endian(redeemer.utxo.output_index, 1))
        |> list.push(own_ref.transaction_id)

    let size_message = #"40"
    let concat_message =
      bytearray.from_string(
        bytearray.to_hex(sha2_256(sha2_256(concat_array(message_array)))),
      )

    let final_message = bytearray.concat(size_message, concat_message)

    let magic_array = bytearray.from_string(magic)
    let final_magic = bytearray.concat(#"19", magic_array)

    let finalized = bytearray.concat(final_magic, final_message)

    let message_hash = keccak_256(finalized)

    //TODO da checkare
    and {
      own_ref == redeemer.utxo,
      validate_signature_key(pubKey, message_hash, redeemer.signature),
    }
  }

  else(_) {
    fail
  }
}

fn validate_signature_key(publicKey: ByteArray, msg: ByteArray, sig: ByteArray) {
  builtin.verify_ecdsa_secp256k1_signature(publicKey, msg, sig)
}

fn concat_array(list_array: List<ByteArray>) {
  list.reduce(list_array, #[], bytearray.concat)
}
