# frozen_string_literal: true

FactoryBot.define do
  factory :external_order do
    source { 'insales' }
    external_order_id { SecureRandom.hex(8) }
    external_order_number { "ORD-#{rand(1000..9999)}" }
    status { 'paid' }
    payment_status { 'paid' }
    total_minor { 15_000 }
    currency { 'RUB' }
    payload_raw { {} }
    last_event_at { Time.current }
  end
end
