class AddExportedToTransactions < ActiveRecord::Migration[7.1]
  def change
    add_column :transactions, :exported, :datetime
  end
end
