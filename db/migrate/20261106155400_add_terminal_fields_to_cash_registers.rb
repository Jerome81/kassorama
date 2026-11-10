class AddTerminalFieldsToCashRegisters < ActiveRecord::Migration[7.1]
  def change
    add_column :cash_registers, :terminal_ip, :string
    add_column :cash_registers, :terminal_port, :integer, default: 4100
  end
end

