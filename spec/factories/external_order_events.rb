# frozen_string_literal: true

FactoryBot.define do
  factory :external_order_event do
    source { 'insales' }
    source_event_id { SecureRandom.uuid }
    association :external_order
    event_type { 'order.updated' }
    event_at { Time.current }
    payload_raw { {} }
    processing_status { 'received' }
  end
end
