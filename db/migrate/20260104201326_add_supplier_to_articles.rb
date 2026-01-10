class AddSupplierToArticles < ActiveRecord::Migration[7.1]
  def change
    add_reference :articles, :supplier, null: true, foreign_key: true
  end
end
