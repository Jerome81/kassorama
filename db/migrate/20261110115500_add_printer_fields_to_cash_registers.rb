class AddPrinterFieldsToCashRegisters < ActiveRecord::Migration[7.1]
  def change
    add_column :cash_registers, :printer_ip, :string
    add_column :cash_registers, :printer_port, :integer, default: 8081
  end
end

