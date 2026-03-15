# frozen_string_literal: true

FactoryBot.define do
  factory :external_fulfillment_operation do
    association :external_order
    operation_type { 'write_off' }
    status { 'queued' }
    idempotency_key { SecureRandom.uuid }
    attempts { 0 }
  end
end
