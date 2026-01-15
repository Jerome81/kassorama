class AddAccountsToRevolutTransactions < ActiveRecord::Migration[7.1]
  def change
    add_column :revolut_transactions, :debit_account, :string
    add_column :revolut_transactions, :credit_account, :string
  end
end
