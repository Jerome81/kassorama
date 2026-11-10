class Order < ApplicationRecord
  belongs_to :cash_register
  has_many :order_items, dependent: :destroy
  has_many :articles, through: :order_items

  accepts_nested_attributes_for :order_items
  
  enum status: { pending: 'pending', completed: 'completed', parked: 'parked' }
  validates :status, presence: true

  def voucher_amount
    return 0.0 if voucher.blank?

    if (m = voucher.to_s.match(/Betrag:\s*(?:CHF\s*)?([0-9]+(?:[.,][0-9]+)?)/i))
      m[1].tr(',', '.').to_f.round(2)
    else
      0.0
    end
  end

  def voucher_code
    return "" if voucher.blank?

    voucher.to_s.sub(/\s*-?\s*Betrag:.*$/i, "").strip
  end
end
