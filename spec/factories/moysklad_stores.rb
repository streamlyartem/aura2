# frozen_string_literal: true

FactoryBot.define do
  factory :moysklad_store do
    sequence(:name) { |n| "Склад #{n}" }
    selected_for_import { false }
    last_seen_at { Time.current }
  end
end
