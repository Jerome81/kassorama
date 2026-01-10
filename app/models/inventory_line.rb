class InventoryLine < ApplicationRecord
  belongs_to :inventory
  belongs_to :article
  belongs_to :location
end
