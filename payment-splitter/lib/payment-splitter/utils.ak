use aiken/hash.{Blake2b_224, Hash}
use aiken/list
use aiken/transaction.{Input, Output, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address, VerificationKey}

pub type VerificationKeyHash =
  Hash<Blake2b_224, VerificationKey>

pub fn must_be_signed_by(transaction: Transaction, vk: VerificationKeyHash) {
  list.has(transaction.extra_signatories, vk)
}

pub fn get_own_input(ctx: ScriptContext) -> Input {
  expect Spend(output_reference) = ctx.purpose
  expect Some(input) =
    list.find(
      ctx.transaction.inputs,
      fn(input) { input.output_reference == output_reference },
    )
  input
}

pub fn get_outputs_by_address(
  outputs: List<Output>,
  address: Address,
) -> List<Output> {
  list.filter(outputs, fn(o) { o.address == address })
}
