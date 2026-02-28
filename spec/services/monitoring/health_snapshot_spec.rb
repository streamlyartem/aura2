# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Monitoring::HealthSnapshot do
  describe '.call' do
    it 'returns operational counts' do
      create(:stock_change_event, priority: 'high', status: 'pending')
      create(:stock_change_event, priority: 'normal', status: 'pending')
      create(:stock_change_event, status: 'processing')
      create(:stock_change_event, status: 'failed')

      stale_run = InsalesSyncRun.create!(
        store_name: 'Тест',
        status: 'running',
        started_at: 2.hours.ago,
        updated_at: 2.hours.ago,
        processed: 0
      )
      InsalesSyncRun.create!(
        store_name: 'Тест',
        status: 'success',
        started_at: 10.minutes.ago,
        finished_at: 9.minutes.ago
      )

      insales_job = SolidQueue::Job.create!(
        queue_name: 'default',
        class_name: 'Insales::SyncProductStocksJob',
        arguments: {},
        scheduled_at: Time.current
      )
      moysklad_job = SolidQueue::Job.create!(
        queue_name: 'default',
        class_name: 'Moysklad::ImportProductsJob',
        arguments: {},
        scheduled_at: Time.current
      )
      SolidQueue::FailedExecution.create!(job: insales_job, error: 'Timeout', created_at: 1.hour.ago)
      SolidQueue::FailedExecution.create!(job: moysklad_job, error: 'HTTP 500', created_at: 2.hours.ago)

      snapshot = described_class.call

      expect(snapshot[:stock_events_pending_high]).to eq(1)
      expect(snapshot[:stock_events_pending_normal]).to eq(1)
      expect(snapshot[:stock_events_processing]).to eq(1)
      expect(snapshot[:stock_events_failed]).to eq(1)
      expect(snapshot[:stale_insales_sync_runs]).to eq(1)
      expect(snapshot[:insales_failed_jobs]).to eq(1)
      expect(snapshot[:moysklad_failed_jobs]).to eq(1)
      expect(snapshot[:failed_jobs_last_24h]).to eq(2)
      expect(snapshot[:p95_insales_sync_seconds]).to eq(60.0)
    end

    it 'returns nil p95 when no finished runs exist' do
      snapshot = described_class.call

      expect(snapshot[:p95_insales_sync_seconds]).to be_nil
    end
  end
end
