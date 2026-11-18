class AddCostToVariants < ActiveRecord::Migration[7.1]
  def change
    add_column :variants, :cost, :decimal, precision: 10, scale: 2
  end
end

