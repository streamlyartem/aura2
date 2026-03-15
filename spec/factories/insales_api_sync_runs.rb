# frozen_string_literal: true

FactoryBot.define do
  factory :insales_api_sync_run do
    run_type { 'upsert' }
    status { 'queued' }
    source { 'aura' }
    batch_id { SecureRandom.uuid }
  end
end
