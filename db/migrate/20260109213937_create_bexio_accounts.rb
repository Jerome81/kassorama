class CreateBexioAccounts < ActiveRecord::Migration[7.1]
  def change
    create_table :bexio_accounts do |t|
      t.string :bexio_id
      t.string :account_number
      t.string :name

      t.timestamps
    end
  end
end
