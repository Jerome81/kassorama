class AddUserNameToTransactions < ActiveRecord::Migration[7.1]
  def change
    add_column :transactions, :user_name, :string
  end
end
