# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Moysklad::ImportProductsJob, type: :job do
  describe '#perform' do
    let(:sync) { instance_double(MoyskladSync, import_products: { processed: 42, stopped: false }) }

    before do
      allow(MoyskladSync).to receive(:new).and_return(sync)
    end

    it 'imports products when lock acquired' do
      allow(described_class).to receive(:with_singleton_lock).and_yield.and_return(true)

      described_class.perform_now

      expect(sync).to have_received(:import_products).with(
        hash_including(
          full_import: true,
          store_names: []
        )
      )
      expect(MoyskladSyncRun.order(:created_at).last).to have_attributes(
        run_type: 'import_products',
        status: 'success',
        processed: 42
      )
    end

    it 'marks run as stopped when stop requested' do
      allow(sync).to receive(:import_products).and_return({ processed: 10, stopped: true })
      allow(described_class).to receive(:with_singleton_lock).and_yield.and_return(true)

      described_class.perform_now(store_names: ['Тест'], full_import: false)

      expect(MoyskladSyncRun.order(:created_at).last).to have_attributes(
        run_type: 'import_products',
        status: 'stopped',
        processed: 10,
        last_error: 'Stopped by user'
      )
    end

    it 'skips import when lock is not acquired' do
      allow(described_class).to receive(:with_singleton_lock).and_return(false)

      described_class.perform_now

      expect(sync).not_to have_received(:import_products)
      expect(MoyskladSyncRun.order(:created_at).last).to have_attributes(
        run_type: 'import_products',
        status: 'skipped'
      )
    end
  end

  describe '.enqueue_once' do
    before do
      allow(described_class).to receive(:perform_later)
    end

    it 'enqueues only when lock acquired and queue empty' do
      allow(described_class).to receive(:queued_or_running?).and_return(false)
      allow(described_class).to receive(:with_singleton_lock).and_yield.and_return(true)

      expect(described_class.enqueue_once(store_names: ['Тест'], full_import: false)).to be(true)
      expect(described_class).to have_received(:perform_later).with(
        store_names: ['Тест'],
        full_import: false
      ).once
    end

    it 'does not enqueue when job is already queued' do
      allow(described_class).to receive(:queued_or_running?).and_return(true)
      allow(described_class).to receive(:with_singleton_lock).and_yield.and_return(true)

      expect(described_class.enqueue_once).to be(false)
      expect(described_class).not_to have_received(:perform_later)
    end

    it 'does not enqueue when previous import is still running' do
      MoyskladSyncRun.create!(run_type: 'import_products', status: 'running', started_at: Time.current)
      allow(described_class).to receive(:queued_or_running?).and_return(false)
      allow(described_class).to receive(:with_singleton_lock).and_yield.and_return(true)

      expect(described_class.enqueue_once).to be(false)
      expect(described_class).not_to have_received(:perform_later)
    end

    it 'enqueues when only stale running imports exist' do
      stale_run = MoyskladSyncRun.create!(
        run_type: 'import_products',
        status: 'running',
        started_at: 2.hours.ago
      )
      allow(described_class).to receive(:queued_or_running?).and_return(false)
      allow(described_class).to receive(:with_singleton_lock).and_yield.and_return(true)

      expect(described_class.enqueue_once(store_names: ['Тест'], full_import: false)).to be(true)
      expect(described_class).to have_received(:perform_later).with(
        store_names: ['Тест'],
        full_import: false
      ).once

      expect(stale_run.reload.status).to eq('stopped')
      expect(stale_run.last_error).to eq('Recovered stale running import')
    end

    it 'does not enqueue when lock is not acquired' do
      allow(described_class).to receive(:with_singleton_lock).and_return(false)

      expect(described_class.enqueue_once).to be(false)
      expect(described_class).not_to have_received(:perform_later)
    end
  end
end
