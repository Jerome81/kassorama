class CashRegister < ApplicationRecord
  belongs_to :stock_location, class_name: "Location", optional: true
  has_many :orders
  has_many :sections, dependent: :destroy
  accepts_nested_attributes_for :sections, allow_destroy: true, reject_if: :all_blank
  has_many :transactions
  validates :name, presence: true
end
