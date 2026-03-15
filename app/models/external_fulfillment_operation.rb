# frozen_string_literal: true

class ExternalFulfillmentOperation < ApplicationRecord
  self.table_name = 'external_fulfillment_operations'

  belongs_to :external_order

  validates :operation_type, :status, :idempotency_key, presence: true
  validates :idempotency_key, uniqueness: true
end
