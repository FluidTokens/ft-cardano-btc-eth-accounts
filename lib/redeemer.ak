use cardano/address.{Address}
use cardano/transaction.{OutputReference}

pub type Redeemer {
  Send {
    signature: ByteArray,
    utxos: List<OutputReference>,
    policy: ByteArray,
    assetname: ByteArray,
    amount: Int,
    policyInput: ByteArray,
    assetnameInput: ByteArray,
    amountInput: Int,
    spendingscriptflag: Int,
    pubkey: ByteArray,
    stakingscriptflag: Int,
    stakekey: ByteArray,
    datumflag: Int,
    datum: Data,
    payment_index: Int,
    fee: Int,
    signer: Address,
  }
  Merge
  Stake { signature: ByteArray, deadline: Int }
}

pub type Redeemermultisig {
  SendMulti {
    signatures: List<Multisignature>,
    utxos: List<OutputReference>,
    policy: ByteArray,
    assetname: ByteArray,
    amount: Int,
    policyInput: ByteArray,
    assetnameInput: ByteArray,
    amountInput: Int,
    spendingscriptflag: Int,
    pubkey: ByteArray,
    stakingscriptflag: Int,
    stakekey: ByteArray,
    datumflag: Int,
    datum: Data,
    payment_index: Int,
    fee: Int,
    signer: Address,
  }
  MergeMulti
  StakeMulti { signatures: List<Multisignature>, deadline: Int }
}

pub type Multisignature {
  signature: ByteArray,
  position: Int,
}
