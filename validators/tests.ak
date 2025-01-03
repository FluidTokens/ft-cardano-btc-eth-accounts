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

pub type RedeemerStake {
  signature: ByteArray,
  deadline: Int,
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

fn generate_redeemer_string_evm(
  redeemer: RedeemerStake,
  poolId: ByteArray,
) -> String {
  let message_array: List<ByteArray> =
    list.push([], poolId)
      |> list.push(bytearray.from_int_big_endian(redeemer.deadline, 20))

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
      #"cb93c9822314f4447028851689b1ea23a18393189577c59d27642e32654e0253",
      0,
    ),
    #"0b77d150c275bd0a600633e4be7d09f83c4b9f00981e22ac9c9d3f62",
    #"0014df1074464c4454",
    1000000,
    #"1c471b31ea0b04c652bd8f76b239aea5f57139bdc5a2b28ab1e69175",
    #"fd3a6bfce30d7744ac55e9cf9146d8a2a04ec7fb2ce2ee6986260653",
  )

test redeemer_string_raul() {
  generate_redeemer_string(test_redeemer) == @"QUALCOSA"
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

const magic_doge =
  @"Dogecoin Signed Message:\n"

fn generate_message_hash_doge(message: String) -> ByteArray {
  let bytes = string.to_bytearray(message)
  let size = length(bytes)

  let final_message =
    bytearray.concat(bytearray.from_int_big_endian(size, 1), bytes)
  let final_magic = bytearray.concat(#"19", bytearray.from_string(magic_doge))

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
  #"8750b5e1e7b2a42e13e73b11b771b9cc3496eee7c6f6c0f1041350d5345f93f0171b737488d1c505a03910a032227bf520e15eb5af7e0b69f81cf41e3aaabd49"

const pubkey =
  #"028fa6b017c4ca1b794c2f5eb6413c3bf2537689c026d75a192a26a01ff86d04b3"

//a57805e57fccecb921cf9acac130b9ca8f76f73fc21ff5c7d04b76849424806e1ee52ad1ef3c5721a9e5ced31ef66afe7e586c8d76349558b20e01f913fb4a8e1c
const signaturevm =
  #"d8db455cab38de6160a738e9b2d72b0814dfd4ec27899025821b82881fc936a7777fae2e11f689a8133968e29f04a2931e3e230fc53afce691141fed5768eefe"

const pubkeyevm =
  #"02598c31a47c10851b9a16c7214dcefebac1959c4b10e5d65f12faef6de11b236c"

const messagevm =
  @"17A587B802ED0368609D20D1CBB4DC32B18982DF6FB27711D3201ED4BEFA32D6"

const messagebtc = @"hello"

test signature_litecoin() {
  let messageHash = generate_message_hash(messagebtc)
  validate_signature_key(pubkey, messageHash, signature) == True
}

test signature_evm() {
  let messageHash = generate_message_hash_evm(messagevm)
  validate_signature_key(pubkeyevm, messageHash, signaturevm) == True
}

fn validate_signature_key(publicKey: ByteArray, msg: ByteArray, sig: ByteArray) {
  builtin.verify_ecdsa_secp256k1_signature(publicKey, msg, sig)
}

const solanapubkey =
  #"0384238a01dd20bc02de4acb035222aa01f647c100ee4e5600b67ab900ce2494028f8bbf003a136c00000000"

const signaturesolana =
  #"e52289e55787f2f00bae066f41449bc5216295e53f1cec593f0b1ab119a9fc6e8f72e509ac9a69f59f008273437065aaef990cbb1d1f47f45e5ab75e64d6ca06"

const messagesolana = #"68656c6c6f"

test signature_solana() {
  validate_signature_solana(solanapubkey, messagesolana, signaturesolana) == True
}

fn validate_signature_solana(
  publicKey: ByteArray,
  msg: ByteArray,
  sig: ByteArray,
) {
  builtin.verify_ed25519_signature(publicKey, msg, sig)
}

const test_redeemer_publish =
  RedeemerStake(
    #"d8db455cab38de6160a738e9b2d72b0814dfd4ec27899025821b82881fc936a7777fae2e11f689a8133968e29f04a2931e3e230fc53afce691141fed5768eefe",
    1734696439051,
  )

test redeemer_string_evm() {
  generate_redeemer_string_evm(
    test_redeemer_publish,
    #"06a9d41c3d9bba41740986a59f484a23967329f1513bc982974aa8bf",
  ) == @"17A587B802ED0368609D20D1CBB4DC32B18982DF6FB27711D3201ED4BEFA32D6"
}

pub type RedeemerReal {
  signature: ByteArray,
  utxos: List<OutputReference>,
  policy: ByteArray,
  assetname: ByteArray,
  amount: Int,
  spendingscriptflag: Int,
  pubkey: ByteArray,
  stakingscriptflag: Int,
  stakekey: ByteArray,
  datumflag: Int,
  datum: Data,
  payment_index: Int,
  fee: Int,
}

const test_redeemer_real =
  RedeemerReal(
    #"ab",
    [
      OutputReference(
        #"cb93c9822314f4447028851689b1ea23a18393189577c59d27642e32654e0253",
        0,
      ),
      OutputReference(
        #"cb93c9822314f4447028851689b1ea23a18393189577c59d27642e32654e0253",
        1,
      ),
    ],
    #"0b77d150c275bd0a600633e4be7d09f83c4b9f00981e22ac9c9d3f62",
    #"0014df1074464c4454",
    1000000,
    0,
    #"1c471b31ea0b04c652bd8f76b239aea5f57139bdc5a2b28ab1e69175",
    0,
    #"fd3a6bfce30d7744ac55e9cf9146d8a2a04ec7fb2ce2ee6986260653",
    0,
    "",
    0,
    1000000,
  )

fn generate_redeemer_array_real(redeemer: RedeemerReal) -> ByteArray {
  let list_utxos =
    list.foldr(
      redeemer.utxos,
      [],
      fn(utxo, xs) {
        [
          utxo.transaction_id,
          bytearray.from_int_big_endian(utxo.output_index, 1),
          ..xs
        ]
      },
    )
  trace cbor.diagnostic(list_utxos)
  expect datum_converted: ByteArray = redeemer.datum
  let message_array: List<ByteArray> =
    list.push([], bytearray.from_int_big_endian(redeemer.fee, 20))
      |> list.push(bytearray.from_int_big_endian(redeemer.payment_index, 1))
      |> list.push(datum_converted)
      |> list.push(bytearray.from_int_big_endian(redeemer.datumflag, 1))
      |> list.push(redeemer.stakekey)
      |> list.push(bytearray.from_int_big_endian(redeemer.stakingscriptflag, 1))
      |> list.push(redeemer.pubkey)
      |> list.push(bytearray.from_int_big_endian(redeemer.spendingscriptflag, 1))
      |> list.push(bytearray.from_int_big_endian(redeemer.amount, 20))
      |> list.push(redeemer.assetname)
      |> list.push(redeemer.policy)

  concat_array(list.concat(list_utxos, message_array))
}

fn generate_redeemer_string_real(redeemer: RedeemerReal) -> String {
  let list_utxos =
    list.foldr(
      redeemer.utxos,
      [],
      fn(utxo, xs) {
        [
          utxo.transaction_id,
          bytearray.from_int_big_endian(utxo.output_index, 1),
          ..xs
        ]
      },
    )
  expect datum_converted: ByteArray = redeemer.datum
  let message_array: List<ByteArray> =
    list.push([], bytearray.from_int_big_endian(redeemer.fee, 20))
      |> list.push(bytearray.from_int_big_endian(redeemer.payment_index, 1))
      |> list.push(datum_converted)
      |> list.push(bytearray.from_int_big_endian(redeemer.datumflag, 1))
      |> list.push(redeemer.stakekey)
      |> list.push(bytearray.from_int_big_endian(redeemer.stakingscriptflag, 1))
      |> list.push(redeemer.pubkey)
      |> list.push(bytearray.from_int_big_endian(redeemer.spendingscriptflag, 1))
      |> list.push(bytearray.from_int_big_endian(redeemer.amount, 20))
      |> list.push(redeemer.assetname)
      |> list.push(redeemer.policy)
      |> list.concat(list_utxos)

  bytearray.to_hex(sha2_256(sha2_256(concat_array(message_array))))
}

test final_test() {
  generate_redeemer_string_real(test_redeemer_real) == @"hello"
}

test final_array() {
  generate_redeemer_array_real(test_redeemer_real) == #""
}
