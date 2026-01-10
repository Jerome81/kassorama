class CreateArticles < ActiveRecord::Migration[7.1]
  def change
    create_table :articles do |t|
      t.string :name
      t.string :sku
      t.string :barcode
      t.decimal :price, precision: 10, scale: 2
      t.decimal :mwst, precision: 4, scale: 1
      t.string :picture
      t.string :status
      t.integer :sales_count

      t.timestamps
    end
    add_index :articles, :sku, unique: true
    add_index :articles, :barcode
  end
end
