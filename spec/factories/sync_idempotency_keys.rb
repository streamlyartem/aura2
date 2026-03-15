# frozen_string_literal: true

FactoryBot.define do
  factory :sync_idempotency_key do
    sequence(:idempotency_key) { |n| "key-#{n}" }
    request_hash { SecureRandom.hex(32) }
    response_status { nil }
    response_body { {} }
    expires_at { 24.hours.from_now }
  end
end
