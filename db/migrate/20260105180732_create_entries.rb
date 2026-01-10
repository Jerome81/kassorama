class CreateEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :entries do |t|
      t.date :booking_date
      t.string :debit_account
      t.string :credit_account
      t.string :description
      t.string :tax_code
      t.decimal :amount
      t.string :reference_number

      t.timestamps
    end
  end
end
