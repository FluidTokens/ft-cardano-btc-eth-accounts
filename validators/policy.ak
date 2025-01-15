use aiken/collection/list
use cardano/address.{Address, Script}
use cardano/assets.{PolicyId}
use cardano/transaction.{Input, Output, Transaction}

validator btc(scriptHash: ByteArray) {
  mint(_redeemer: Data, _policy: PolicyId, self: Transaction) {
    is_sc_present(self.inputs, scriptHash)
    //we'll build the message like this,txid+index+unit+amount+pubkey+stakekeys
  }

  else(_) {
    fail
  }
}

fn is_sc_present(inputs: List<Input>, sc_hash: ByteArray) {
  list.any(
    inputs,
    fn(input) { input.output.address.payment_credential == Script(sc_hash) },
  )
}
