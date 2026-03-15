# frozen_string_literal: true

class ExternalOrder < ApplicationRecord
  self.table_name = 'external_orders'

  has_many :external_order_items, dependent: :delete_all
  has_many :external_order_events, dependent: :nullify
  has_many :external_fulfillment_operations, dependent: :delete_all

  validates :source, :external_order_id, :status, presence: true
  validates :external_order_id, uniqueness: { scope: :source }
end
