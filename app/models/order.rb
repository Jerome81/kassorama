class Order < ApplicationRecord
  belongs_to :cash_register
  has_many :order_items, dependent: :destroy
  has_many :articles, through: :order_items

  accepts_nested_attributes_for :order_items
  
  enum status: { pending: 'pending', completed: 'completed', parked: 'parked' }
  validates :status, presence: true
end
