class AddExportedToOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :orders, :exported, :datetime
  end
end
