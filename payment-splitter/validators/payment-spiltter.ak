use aiken/list
use aiken/transaction.{
  InlineDatum, Input, Output, ScriptContext, Spend, Transaction,
}
use aiken/transaction/value
use payment_splitter/utils.{
  VerificationKeyHash, get_outputs_by_address, get_own_input, must_be_signed_by,
}

// Define the data structure to hold the state of the contract
pub type Datum {
  totalShares: Int,
  // Total shares in the contract
  totalReleased: Int,
  // Total amount released from the contract
  payees: List<Payee>,
}

// List of payees

// Define the data structure for each payee
pub type Payee {
  account: VerificationKeyHash,
  // Account address of the payee
  shares: Int,
  // Number of shares assigned to the payee
  released: Int,
}

// Amount released to the payee

// Define the actions that can be performed on the contract
pub type Redeemer {
  AddPayee(VerificationKeyHash, Int)
  // Action to add a new payee
  Release(VerificationKeyHash)
}

// Action to release funds to a payee

// Main validator function for the contract
validator {
  fn payment_splitter(datum: Datum, redeemer: Redeemer, ctx: ScriptContext) {
    let tx = ctx.transaction
    // Get the transaction context
    let own_input = get_own_input(ctx)
    // Get the input associated with the contract
    let contract_address = own_input.output.address

    // Get the contract's address
    let contract_outputs = get_outputs_by_address(tx.outputs, contract_address)

    // Get the outputs associated with the contract's address
    when ctx.purpose is {
      Spend(_) ->
        when redeemer is {
          // Logic to add a new payee
          AddPayee(account, shares) -> {
            // Ensure payees list is not empty and get the creator account
            expect Some(creator_payee) = list.head(datum.payees)
            let creator_account = creator_payee.account

            // Ensure the transaction is signed by the creator
            expect must_be_signed_by(tx, creator_account)

            // Ensure the account is not already a payee and shares are greater than 0
            expect
              list.find(datum.payees, fn(payee) { payee.account == account }) == None
            expect shares > 0

            // Create the new payee
            let new_payee = Payee { account, shares, released: 0 }

            // Update the list of payees
            let updated_payees = list.concat(datum.payees, [new_payee])
            let updated_datum =
              Datum {
                totalShares: datum.totalShares + shares,
                totalReleased: datum.totalReleased,
                payees: updated_payees,
              }

            // Ensure there is exactly one output and update the datum
            expect list.length(contract_outputs) == 1
            expect Some(contract_output) = list.at(contract_outputs, 0)
            expect InlineDatum(untyped_datum) = contract_output.datum
            expect contract_output_datum: Datum = untyped_datum

            // Validate the updated datum
            contract_output_datum == updated_datum
          }

          // Logic to release funds to a payee
          Release(account) -> {
            // Find the payee in the list of payees
            let payee =
              list.find(datum.payees, fn(payee) { payee.account == account })
            expect Some(payee) = payee

            // Calculate the total received and payment amount
            let totalReceived =
              value.lovelace_of(own_input.output.value) + datum.totalReleased
            let payment =
              totalReceived * payee.shares / datum.totalShares - payee.released
            expect payment > 0

            // Update the payee with the released amount
            let updated_payee =
              Payee {
                account: payee.account,
                shares: payee.shares,
                released: payee.released + payment,
              }

            // Update the list of payees
            let updated_payees =
              list.map(
                datum.payees,
                fn(payee) {
                  if payee.account == account {
                    updated_payee
                  } else {
                    payee
                  }
                },
              )

            // Update the datum with the new total released amount
            let updated_datum =
              Datum {
                totalShares: datum.totalShares,
                totalReleased: datum.totalReleased + payment,
                payees: updated_payees,
              }

            // Ensure there is exactly one output and update the datum
            expect list.length(contract_outputs) == 1
            expect Some(contract_output) = list.at(contract_outputs, 0)
            expect InlineDatum(untyped_datum) = contract_output.datum
            expect contract_output_datum: Datum = untyped_datum

            // Validate the updated datum
            contract_output_datum == updated_datum
          }
        }
      _ -> False
    }
  }
}
