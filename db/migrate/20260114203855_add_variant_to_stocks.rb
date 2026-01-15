class AddVariantToStocks < ActiveRecord::Migration[7.1]
  def change
    add_reference :stocks, :variant, null: true, foreign_key: true
  end
end
