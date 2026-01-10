class Stock < ApplicationRecord
  belongs_to :article
  belongs_to :location

  validates :quantity, numericality: { only_integer: true }
  validates :article_id, uniqueness: { scope: :location_id }
end
