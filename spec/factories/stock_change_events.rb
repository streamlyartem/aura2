# frozen_string_literal: true

FactoryBot.define do
  factory :stock_change_event do
    association :product
    priority { "normal" }
    reason { "stock_changed" }
    event_updated_at { Time.current }
    status { "pending" }
    attempts { 0 }
  end
end
