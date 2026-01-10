class Location < ApplicationRecord
  has_many :stocks, dependent: :destroy
  has_many :articles, through: :stocks

  validates :name, presence: true
end
