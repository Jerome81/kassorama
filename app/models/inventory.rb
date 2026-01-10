class Inventory < ApplicationRecord
  has_many :inventory_lines, dependent: :destroy
  after_create :snapshot_stocks

  private

  def snapshot_stocks
    # Copy all current stock records to inventory lines
    Stock.find_each do |stock|
      inventory_lines.create(
        article: stock.article,
        location: stock.location,
        quantity: stock.quantity,
        diff: 0
      )
    end
  end
end
