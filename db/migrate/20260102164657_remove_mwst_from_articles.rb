class RemoveMwstFromArticles < ActiveRecord::Migration[7.1]
  def change
    remove_column :articles, :mwst, :decimal
  end
end
