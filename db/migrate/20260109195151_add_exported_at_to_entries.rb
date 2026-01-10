class AddExportedAtToEntries < ActiveRecord::Migration[7.1]
  def change
    add_column :entries, :exported_at, :datetime
  end
end
