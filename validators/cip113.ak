use aiken/collection/dict
use aiken/collection/list
use aiken/collection/pairs.{has_key}
use cardano/address.{Address, Credential, Inline, Script, VerificationKey}
use cardano/assets.{PolicyId, quantity_of}
use cardano/transaction.{Input, Output, OutputReference, Redeemer, Transaction}

//cardano pubkeyhash
//eth pubkey
//btc/doge/litecoin pubkey

const assetName = "realUSDC"

validator transfer {
  spend(
    _datum: Option<Data>,
    _redeemer: Data,
    own_ref: OutputReference,
    self: Transaction,
  ) {
    expect Some(input) =
      self.inputs
        |> transaction.find_input(own_ref)

    expect Script(hash) = input.output.address.payment_credential

    let account = Script(hash)
    has_key(self.withdrawals, account)
  }

  withdraw(_redeemer: Redeemer, account: Credential, self: Transaction) {
    //even if there are different addresses involved, the patricia trie is the same, so one reference input
    token_with_credentials_in_contract(account, self)
  }

  mint(_redeemer: Data, policy: PolicyId, self: Transaction) {
    //elraulito is the only one able to mint
    let account = Script(policy)
    and {
      or {
        is_owner_signing(
          #"66ec634b007c666a96a8e4b89c621a6dfebf29390948f8ecc047faf2",
          self,
        ),
        is_owner_signing(
          #"96cbb27c96daf8cab890de6d7f87f5ffd025bf8ac80717cbc4fae7da",
          self,
        ),
      },
      token_with_credentials_in_contract(account, self),
    }
  }

  else(_) {
    fail
  }
}

pub fn token_with_credentials_in_contract(
  account: Credential,
  self: Transaction,
) {
  expect Script(hash) = account
  let inputs_contract = get_input_contract(self.inputs, hash)
  //first thing is that for each input the credentials are correct
  and {
    list.all(
      inputs_contract,
      fn(input) {
        expect Some(stake_cred) = input.output.address.stake_credential
        expect Inline(a) = stake_cred
        expect VerificationKey(hash) = a
        is_owner_signing(hash, self)
      },
    ),
    get_input_token_contract(self.inputs, hash) + quantity_of(
      self.mint,
      hash,
      assetName,
    ) == get_output_token_contract(self.outputs, hash),
  }
}

fn is_owner_signing(hash: ByteArray, tx: Transaction) {
  let fst_token_quantity =
    tx.mint
      |> assets.tokens(hash)
      |> dict.size()
  or {
    list.has(tx.extra_signatories, hash),
    has_key(tx.withdrawals, Script(hash)),
    list.any(
      tx.inputs,
      fn(input) {
        let Input { output, .. } = input
        let Output { address: out_address, .. } = output
        let Address { payment_credential: out_payment_credential, .. } =
          out_address
        out_payment_credential == VerificationKey(hash)
      },
    ),
    fst_token_quantity != 0,
  }
  //IMO even 0 is ok to allow multisignatures, however how can we validate that the policy is present?
}

pub fn get_input_contract(inputs: List<Input>, contract: ByteArray) {
  list.filter(
    inputs,
    fn(input) { input.output.address.payment_credential == Script(contract) },
  )
}

pub fn get_input_token_contract(inputs: List<Input>, contract: ByteArray) {
  list.foldl(
    inputs,
    0,
    fn(input, total) {
      when input.output.address.payment_credential is {
        Script(hash) ->
          if hash == contract {
            quantity_of(input.output.value, contract, assetName) + total
          } else {
            total
          }
        _ -> total
      }
    },
  )
}

pub fn get_output_token_contract(outputs: List<Output>, contract: ByteArray) {
  list.foldl(
    outputs,
    0,
    fn(output, total) {
      when output.address.payment_credential is {
        Script(hash) ->
          if hash == contract {
            quantity_of(output.value, contract, assetName) + total
          } else {
            total
          }
        _ -> total
      }
    },
  )
}
