class AddSkuToVariants < ActiveRecord::Migration[7.1]
  def change
    add_column :variants, :sku, :string
  end
end
