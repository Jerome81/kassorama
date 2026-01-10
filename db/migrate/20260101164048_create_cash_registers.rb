class CreateCashRegisters < ActiveRecord::Migration[7.1]
  def change
    create_table :cash_registers do |t|
      t.string :name
      t.string :status

      t.timestamps
    end
  end
end
