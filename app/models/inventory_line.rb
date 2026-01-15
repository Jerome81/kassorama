class InventoryLine < ApplicationRecord
  belongs_to :inventory
  belongs_to :article
  belongs_to :location
  belongs_to :variant, optional: true
end
