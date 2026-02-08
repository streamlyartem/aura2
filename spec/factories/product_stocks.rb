# frozen_string_literal: true

FactoryBot.define do
  factory :product_stock do
    association :product

    store_name { 'Основной склад' }
    stock { rand(1..100) }
    synced_at { Time.current }

    trait :zero_stock do
      stock { 0 }
    end

    trait :recent do
      synced_at { 1.hour.ago }
    end
  end
end
