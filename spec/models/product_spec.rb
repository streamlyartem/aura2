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
  end
end
