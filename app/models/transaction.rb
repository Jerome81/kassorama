class Transaction < ApplicationRecord
  belongs_to :cash_register, optional: true
end
