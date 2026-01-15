class CreateRevolutTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :revolut_transactions do |t|
      t.date :date
      t.string :state
      t.string :description
      t.string :payer
      t.decimal :original_amount
      t.string :original_currency
      t.decimal :total_amount

      t.timestamps
    end
  end
end
