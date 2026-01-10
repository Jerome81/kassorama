class AddPrecreatedTabsToCashRegisters < ActiveRecord::Migration[7.1]
  def change
    add_column :cash_registers, :precreated_tabs, :string
  end
end
