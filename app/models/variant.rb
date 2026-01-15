class Variant < ApplicationRecord
  belongs_to :article
  has_one_attached :image
  has_many :stocks, dependent: :destroy
  has_many :order_items
end
