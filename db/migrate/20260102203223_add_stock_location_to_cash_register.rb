class AddStockLocationToCashRegister < ActiveRecord::Migration[7.1]
  def change
    add_reference :cash_registers, :stock_location, null: true, foreign_key: { to_table: :locations }
  end
end
