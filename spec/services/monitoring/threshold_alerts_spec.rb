# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Monitoring::ThresholdAlerts do
  let(:cache_store) { ActiveSupport::Cache::MemoryStore.new }

  before do
    allow(Rails).to receive(:cache).and_return(cache_store)
    Rails.cache.clear
    allow(Monitoring::SentryReporter).to receive(:report_operational_alert)
  end

  describe '.check_stock_pipeline!' do
    it 'reports when pending_high crosses threshold and does not spam immediately' do
      stub_const('Monitoring::ThresholdAlerts::ALERT_COOLDOWN', 10.minutes)
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('MONITOR_STOCK_PENDING_HIGH_ALERT', 100).and_return('2')
      allow(ENV).to receive(:fetch).with('MONITOR_STOCK_PENDING_NORMAL_ALERT', 5000).and_return('999999')
      allow(ENV).to receive(:fetch).with('MONITOR_STOCK_RETRY_DUE_ALERT', 50).and_return('999999')
      allow(ENV).to receive(:fetch).with('MONITOR_STOCK_HTTP_429_24H_ALERT', 20).and_return('999999')

      described_class.check_stock_pipeline!(pending_high: 3, pending_normal: 0)
      described_class.check_stock_pipeline!(pending_high: 3, pending_normal: 0)

      expect(Monitoring::SentryReporter).to have_received(:report_operational_alert)
        .with(hash_including(message: 'Stock events pending high above threshold: 3'))
        .once
    end
  end

  describe '.check_api_v1_runs!' do
    it 'reports when failed runs threshold is exceeded' do
      create(:insales_api_sync_run, status: 'failed', created_at: 10.minutes.ago)
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('MONITOR_API_V1_FAILED_1H_ALERT', 1).and_return('1')

      described_class.check_api_v1_runs!

      expect(Monitoring::SentryReporter).to have_received(:report_operational_alert)
        .with(hash_including(message: 'API v1 failed runs over last hour: 1'))
        .once
    end
  end
end
