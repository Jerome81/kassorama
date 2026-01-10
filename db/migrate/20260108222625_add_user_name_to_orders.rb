class AddUserNameToOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :orders, :user_name, :string
  end
end
