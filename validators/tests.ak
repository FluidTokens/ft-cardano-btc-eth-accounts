use aiken/builtin
use aiken/cbor
use aiken/collection/list
use aiken/crypto.{keccak_256, sha2_256}
use aiken/primitive/bytearray.{length}
use aiken/primitive/int.{to_string}
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
  trace cbor.diagnostic(concat_array(message_array))
  trace cbor.diagnostic(sha2_256(concat_array(message_array)))
  trace cbor.diagnostic(sha2_256(sha2_256(concat_array(message_array))))
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
      #"f5050ca4ce13f459efbd199fec2d62605eca9165fbec9201df8fbda7142a0dc7",
      0,
    ),
    #"",
    #"",
    5000000,
    #"1c471b31ea0b04c652bd8f76b239aea5f57139bdc5a2b28ab1e69175",
    #"fd3a6bfce30d7744ac55e9cf9146d8a2a04ec7fb2ce2ee6986260653",
  )

test redeemer_string_raul() {
  generate_redeemer_string(test_redeemer) == @"F321DACF3F1DA673C6E08385EC1750007D445E65EA5EFBFCE3F8D9076944589C"
}

test add_one_redeem() {
  add_one(test_redeemer) == #"4038383438323732344433453142343239394430303532324441363233464343343044423145393143384435444433413731323532324241303135463546333044"
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

const magicevm =
  @"Ethereum Signed Message:\n"

fn generate_message_hash_evm(message: String) -> ByteArray {
  let bytes = string.to_bytearray(message)
  let size = string.to_bytearray(to_string(length(bytes)))

  let final_message = bytearray.concat(size, bytes)
  let final_magic = bytearray.concat(#"19", bytearray.from_string(magicevm))

  let finalized = bytearray.concat(final_magic, final_message)
  trace cbor.diagnostic(finalized)
  let message_hash = keccak_256(finalized)
  message_hash
}

const signature =
  #"d0c0720de80a3ae3b7a387f4e0bdec1ce0bc7cf7d6d8129edf5259fe34fb86e0578ca385ab111968880ac30d8c8770536fd1f61e804e88f7145618cee49d29ad"

const pubkey =
  #"035a99c71780945305f3a20356d55bcc7e8b681c3ef84c537cee5ee7e7da23163e"

//a57805e57fccecb921cf9acac130b9ca8f76f73fc21ff5c7d04b76849424806e1ee52ad1ef3c5721a9e5ced31ef66afe7e586c8d76349558b20e01f913fb4a8e1c
const signaturevm =
  #"8c31abea17da50f76f11af8be147bff50efa3651d68a4c981f2d161ae0f78aab5656400a01bfb9f4ae75f2ed732371189d002df5ee9bf593970226bd6970117b"

const pubkeyevm =
  #"03d60f06fdfc20cde4cabf176237101424b141ba2fae5fb621717d4192f292c0a2"

const messagevm = @"hello"

test signature_evm() {
  let messageHash = generate_message_hash_evm(messagevm)
  trace cbor.diagnostic(messageHash)
  trace @"needs to be"
  trace #"50b2c43fd39106bafbba0da34fc430e1f91e3c96ea2acee2bc34119f92b37750"
  validate_signature_key(
    pubkeyevm,
    #"50b2c43fd39106bafbba0da34fc430e1f91e3c96ea2acee2bc34119f92b37750",
    signaturevm,
  ) == True
}

fn validate_signature_key(publicKey: ByteArray, msg: ByteArray, sig: ByteArray) {
  builtin.verify_ecdsa_secp256k1_signature(publicKey, msg, sig)
}
