class AddTaxCodeToRevolutTransactions < ActiveRecord::Migration[7.1]
  def change
    add_column :revolut_transactions, :tax_code, :string
  end
end
