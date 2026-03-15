# frozen_string_literal: true

FactoryBot.define do
  factory :sync_outbox_event do
    aggregate_type { 'Product' }
    aggregate_id { SecureRandom.uuid }
    event_type { 'product.updated' }
    payload { { external_id: aggregate_id, sku: 'SKU-1' } }
    occurred_at { Time.current }
  end
end
