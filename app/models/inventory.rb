class Inventory < ApplicationRecord
  has_many :inventory_lines, dependent: :destroy
  after_create :snapshot_stocks

  private

  def snapshot_stocks
    # Copy all current stock records to inventory lines
    Stock.find_each do |stock|
      next if stock.quantity.nil? || stock.quantity == 0

      inventory_lines.create!(
        article_id: stock.article_id,
        location_id: stock.location_id,
        variant_id: stock.variant_id,
        quantity: stock.quantity,
        diff: 0
      )
    end
  end
end
