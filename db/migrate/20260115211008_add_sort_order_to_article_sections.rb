class AddSortOrderToArticleSections < ActiveRecord::Migration[7.1]
  def change
    add_column :article_sections, :sort_order, :integer
  end
end
