# frozen_string_literal: true

class ExternalOrderItem < ApplicationRecord
  self.table_name = 'external_order_items'

  belongs_to :external_order
  belongs_to :product, optional: true

  validates :sku, :quantity, presence: true
end
