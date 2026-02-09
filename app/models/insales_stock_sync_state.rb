# frozen_string_literal: true

class InsalesStockSyncState < ApplicationRecord
  validates :store_name, presence: true, uniqueness: true
end
