class AddCashRegisterToTransactions < ActiveRecord::Migration[7.1]
  def change
    add_reference :transactions, :cash_register, null: true, foreign_key: true
  end
end
