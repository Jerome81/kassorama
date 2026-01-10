class AddCompletedAtToInventory < ActiveRecord::Migration[7.1]
  def change
    add_column :inventories, :completed_at, :datetime
  end
end
