class AddAmountToCashRegister < ActiveRecord::Migration[7.1]
  def change
    add_column :cash_registers, :amount, :decimal, precision: 10, scale: 2, default: 0
  end
end
