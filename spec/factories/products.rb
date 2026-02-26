# frozen_string_literal: true

FactoryBot.define do
  factory :product do
    sequence(:name) { |n| "Product #{n}" }
    sequence(:sku) { |n| "SKU-#{n.to_s.rjust(4, '0')}" }
    ms_id { SecureRandom.uuid }
    unit_type { 'weight' }
    unit_weight_g { 1.0 }
    retail_price { 0 }
  end
end
