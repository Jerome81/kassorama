class AddGroupAndTaxCodeToArticles < ActiveRecord::Migration[7.1]
  def change
    add_column :articles, :group, :string
    add_reference :articles, :tax_code, null: true, foreign_key: true
  end
end
