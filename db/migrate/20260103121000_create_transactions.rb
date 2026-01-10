class CreateTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :transactions do |t|
      t.string :transaction_type
      t.decimal :amount, precision: 10, scale: 2
      t.string :description

      t.timestamps
    end
  end
end
