class RemoveGroupFromArticlesAndSections < ActiveRecord::Migration[7.1]
  def change
    remove_column :articles, :group, :string
    remove_column :sections, :group_filter, :string
  end
end
