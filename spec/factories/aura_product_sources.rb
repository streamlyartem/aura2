# frozen_string_literal: true

FactoryBot.define do
  factory :aura_product_source do
    sequence(:code) { |n| "source_#{n}" }
    sequence(:name) { |n| "Источник #{n}" }
    source_kind { 'moysklad' }
    priority { 100 }
    active { true }
    authoritative { false }
    settings { {} }
  end
end
