# frozen_string_literal: true

FactoryBot.define do
  factory :external_order_item do
    association :external_order
    sku { "SKU-#{SecureRandom.hex(3)}" }
    quantity { 1 }
    unit_price_minor { 10_000 }
    currency { 'RUB' }
    meta { {} }
  end
end
