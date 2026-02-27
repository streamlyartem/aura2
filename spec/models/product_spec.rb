# frozen_string_literal: true

require 'models/concerns/models_shared_examples'
require 'rails_helper'

RSpec.describe Product do
  it { is_expected.to have_many(:images).dependent(:destroy) }

  it_behaves_like 'sets implicit order column', :created_at

  describe 'callbacks' do
    it 'enqueues insales trigger job after create and update' do
      ActiveJob::Base.queue_adapter = :test

      product = nil
      expect do
        product = create(:product)
      end.to have_enqueued_job(Insales::SyncProductTriggerJob).with(
        product_id: kind_of(String),
        reason: 'product_changed'
      )

      ActiveJob::Base.queue_adapter.enqueued_jobs.clear

      expect do
        product.update!(name: 'Renamed')
      end.to have_enqueued_job(Insales::SyncProductTriggerJob).with(
        product_id: product.id,
        reason: 'product_changed'
      )
    end

    it 'does not enqueue trigger for touch-only updates' do
      ActiveJob::Base.queue_adapter = :test
      product = create(:product)
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear

      expect do
        product.touch
      end.not_to have_enqueued_job(Insales::SyncProductTriggerJob)
    end

    it 'does not enqueue trigger while moysklad import flag is set' do
      ActiveJob::Base.queue_adapter = :test
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear

      expect do
        Current.set(skip_insales_product_sync: true) { create(:product) }
      end.not_to have_enqueued_job(Insales::SyncProductTriggerJob)
    end
  end

  describe '.find_by_scanned_barcode' do
    it 'matches barcode when scanned value has extra leading zeroes' do
      product = create(:product, sku: '1805327132', code: '1805327132', barcodes: [{ 'code128' => '001805327132' }])

      found = described_class.find_by_scanned_barcode('0001805327132')

      expect(found).to eq(product)
    end
  end
end
