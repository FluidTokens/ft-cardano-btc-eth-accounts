use aiken/builtin
use aiken/cbor
use aiken/collection/list
use aiken/crypto.{sha2_256}
use aiken/primitive/bytearray.{length}
use aiken/primitive/string
use cardano/transaction.{OutputReference}

pub type Redeemer {
  signature: ByteArray,
  utxo: OutputReference,
  policy: ByteArray,
  assetname: ByteArray,
  amount: Int,
  pubkey: ByteArray,
  stakekey: ByteArray,
}

fn add_one(redeemer: Redeemer) -> ByteArray {
  let message_string_to_sign = generate_redeemer_string(redeemer)
  let size_message = #"40"
  let concat_message = bytearray.from_string(message_string_to_sign)

  //il doppio sha poi lo rendo stringa e maiuscolo, è quello che firmo
  let final_message = bytearray.concat(size_message, concat_message)
  final_message
}

fn generate_redeemer_string(redeemer: Redeemer) -> String {
  let message_array: List<ByteArray> =
    list.push([], redeemer.stakekey)
      |> list.push(redeemer.pubkey)
      |> list.push(bytearray.from_int_big_endian(redeemer.amount, 20))
      |> list.push(redeemer.assetname)
      |> list.push(redeemer.policy)
      |> list.push(bytearray.from_int_big_endian(redeemer.utxo.output_index, 1))
      |> list.push(redeemer.utxo.transaction_id)
  bytearray.to_hex(sha2_256(sha2_256(concat_array(message_array))))
}

fn generate_redeemer_array(redeemer: Redeemer) -> ByteArray {
  let message_array: List<ByteArray> =
    list.push([], redeemer.stakekey)
      |> list.push(redeemer.pubkey)
      |> list.push(bytearray.from_int_big_endian(redeemer.amount, 20))
      |> list.push(redeemer.assetname)
      |> list.push(redeemer.policy)
      |> list.push(bytearray.from_int_big_endian(redeemer.utxo.output_index, 1))
      |> list.push(redeemer.utxo.transaction_id)
  concat_array(message_array)
}

const test_redeemer =
  Redeemer(
    #"ab",
    OutputReference(
      #"6f69a8ed4e307bfb1d29e79f223c2bbf1debbb4c632bce72e2e3b8043a685224",
      0,
    ),
    #"",
    #"",
    5000000,
    #"1c471b31ea0b04c652bd8f76b239aea5f57139bdc5a2b28ab1e69175",
    #"fd3a6bfce30d7744ac55e9cf9146d8a2a04ec7fb2ce2ee6986260653",
  )

test redeemer_string() {
  generate_redeemer_string(test_redeemer) == @"5E181DB6BB8A42C28CCE87A97DCBB4E35A8C3320A13DDFCFB302F4F05D8E858B"
}

test add_one_redeem() {
  add_one(test_redeemer) == #"4035453138314442364242384134324332384343453837413937444342423445333541384333333230413133444446434642333032463446303544384538353842"
}

fn concat_array(list_array: List<ByteArray>) {
  list.reduce(list_array, #[], bytearray.concat)
}

const magic =
  @"Bitcoin Signed Message:\n"

fn generate_message_hash(message: String) -> ByteArray {
  let bytes = string.to_bytearray(message)
  let size = length(bytes)

  let final_message =
    bytearray.concat(bytearray.from_int_big_endian(size, 1), bytes)
  let final_magic = bytearray.concat(#"18", bytearray.from_string(magic))

  let finalized = bytearray.concat(final_magic, final_message)

  let message_hash = sha2_256(sha2_256(finalized))
  message_hash
}

const signature =
  #"632aacb01029a986a0f4b11c304daa3881a94ad027b3a357efd1ade3e1915412690d5a04d62cd65412e56d08a25aa73029b59023afd7ad8e4765d674550d330b"

const pubkey =
  #"028f5ced5649da371758f280635f94a558c68eee2ac4c7f07034425e97c60352bd"

test signature_test() {
  let messageHash =
    generate_message_hash(
      @"ABACADABA9F12A8B5382FC370E4E7E69421FB59831BB4ECCA3A11D9B",
    )
  trace cbor.diagnostic(messageHash)
  validate_signature_key(pubkey, messageHash, signature) == True
}

test signature_test_two() {
  trace @"firma questo"
  trace cbor.diagnostic(
    sha2_256(
      sha2_256(#"abacadaba9f12a8b5382fc370e4e7e69421fb59831bb4ecca3a11d9b"),
    ),
  )
  let messageHash =
    generate_message_hash(
      @"ABACADABA9F12A8B5382FC370E4E7E69421FB59831BB4ECCA3A11D9B",
    )
  messageHash == #"71495e556b24afaa17d4318cef55b21a8ac341a12b1080f1ef602641708833cf"
}

test generate_array() {
  generate_redeemer_array(test_redeemer) == #"6f69a8ed4e307bfb1d29e79f223c2bbf1debbb4c632bce72e2e3b8043a6852240000000000000000000000000000000000004c4b401c471b31ea0b04c652bd8f76b239aea5f57139bdc5a2b28ab1e69175fd3a6bfce30d7744ac55e9cf9146d8a2a04ec7fb2ce2ee6986260653"
}

fn validate_signature_key(publicKey: ByteArray, msg: ByteArray, sig: ByteArray) {
  builtin.verify_ecdsa_secp256k1_signature(publicKey, msg, sig)
}
