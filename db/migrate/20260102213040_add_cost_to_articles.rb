class AddCostToArticles < ActiveRecord::Migration[7.1]
  def change
    add_column :articles, :cost, :decimal, precision: 10, scale: 2
  end
end
