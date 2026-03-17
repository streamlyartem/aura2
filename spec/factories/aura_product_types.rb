# frozen_string_literal: true

FactoryBot.define do
  factory :aura_product_type do
    sequence(:code) { |n| "type_#{n}" }
    sequence(:name) { |n| "Тип #{n}" }
    priority { 100 }
    active { true }
    weight_from_stock { false }
  end
end
