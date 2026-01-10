class AddDiffToInventoryLine < ActiveRecord::Migration[7.1]
  def change
    add_column :inventory_lines, :diff, :integer
  end
end
