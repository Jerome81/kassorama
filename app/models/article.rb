class Article < ApplicationRecord
  belongs_to :tax_code
  belongs_to :article_category, optional: true
  belongs_to :supplier, optional: true
  has_many :stocks, dependent: :destroy
  has_many :locations, through: :stocks
  has_many :article_sections, dependent: :destroy
  has_many :sections, through: :article_sections
  has_many :order_items

  validates :name, presence: true
  validates :sku, presence: true, uniqueness: true
  validates :barcode, presence: true, uniqueness: true
  enum price_type: { fixed: 'fixed', free: 'free' }
  validates :price_type, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
