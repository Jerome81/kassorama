class Stock < ApplicationRecord
  belongs_to :article
  belongs_to :location
  belongs_to :variant, optional: true

  validates :quantity, numericality: { only_integer: true }
  validates :article_id, uniqueness: { scope: [:location_id, :variant_id] }
end
