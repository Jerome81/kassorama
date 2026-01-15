class AddExportedToRevolutTransactions < ActiveRecord::Migration[7.1]
  def change
    add_column :revolut_transactions, :exported, :date
  end
end
