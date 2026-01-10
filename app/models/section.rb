class Section < ApplicationRecord
  belongs_to :cash_register
  has_many :article_sections, dependent: :destroy
  has_many :articles, through: :article_sections
  validates :name, presence: true
  validates :group_filter, presence: true
end
