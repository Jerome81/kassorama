class CreateStocks < ActiveRecord::Migration[7.1]
  def change
    create_table :stocks do |t|
      t.references :article, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.integer :quantity

      t.timestamps
    end
  end
end
