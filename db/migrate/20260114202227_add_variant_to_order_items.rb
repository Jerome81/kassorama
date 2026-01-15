class AddVariantToOrderItems < ActiveRecord::Migration[7.1]
  def change
    add_reference :order_items, :variant, null: true, foreign_key: true
  end
end
