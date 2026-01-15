class AddVariantToInventoryLines < ActiveRecord::Migration[7.1]
  def change
    add_reference :inventory_lines, :variant, null: true, foreign_key: true
  end
end
