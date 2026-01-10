class AddPricingFieldsToOrderItems < ActiveRecord::Migration[7.1]
  def change
    add_column :order_items, :gross_price, :decimal, precision: 10, scale: 2
    add_column :order_items, :discount, :decimal, precision: 10, scale: 2
    add_column :order_items, :net_price, :decimal, precision: 10, scale: 2
  end
end
