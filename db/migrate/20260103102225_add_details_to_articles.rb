class AddDetailsToArticles < ActiveRecord::Migration[7.1]
  def change
    add_column :articles, :price_type, :string, default: 'fixed'
    add_column :articles, :is_voucher, :boolean, default: false
  end
end
