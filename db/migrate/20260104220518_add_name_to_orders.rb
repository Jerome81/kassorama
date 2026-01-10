class AddNameToOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :orders, :name, :string
  end
end
