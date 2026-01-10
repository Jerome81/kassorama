class AddBookingAccountToArticles < ActiveRecord::Migration[7.1]
  def change
    add_column :articles, :booking_account, :string
  end
end
