class CreateVariants < ActiveRecord::Migration[7.1]
  def change
    create_table :variants do |t|
      t.references :article, null: false, foreign_key: true
      t.string :name
      t.string :barcode
      t.decimal :price, precision: 10, scale: 2
      t.string :picture

      t.timestamps
    end
  end
end
