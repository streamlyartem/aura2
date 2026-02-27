# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InsalesSyncRun do
  describe '.recover_stale_runs!' do
    it 'marks stale running runs as stopped when no claimed sync jobs exist' do
      stale = described_class.create!(
        store_name: 'Тест',
        status: 'running',
        finished_at: nil,
        started_at: 3.hours.ago,
        processed: 0,
        updated_at: 3.hours.ago
      )
      fresh = described_class.create!(
        store_name: 'Тест',
        status: 'running',
        finished_at: nil,
        started_at: 10.minutes.ago,
        processed: 0
      )

      allow(described_class).to receive(:sync_job_claimed?).and_return(false)

      updated = described_class.recover_stale_runs!(ttl: 45.minutes)

      expect(updated).to eq(1)
      expect(stale.reload.status).to eq('stopped')
      expect(stale.finished_at).to be_present
      expect(fresh.reload.status).to eq('running')
    end

    it 'does nothing while sync job is actively claimed' do
      stale = described_class.create!(
        store_name: 'Тест',
        status: 'running',
        finished_at: nil,
        started_at: 3.hours.ago,
        processed: 0,
        updated_at: 3.hours.ago
      )

      allow(described_class).to receive(:sync_job_claimed?).and_return(true)

      updated = described_class.recover_stale_runs!(ttl: 45.minutes)

      expect(updated).to eq(0)
      expect(stale.reload.status).to eq('running')
    end
  end
end
