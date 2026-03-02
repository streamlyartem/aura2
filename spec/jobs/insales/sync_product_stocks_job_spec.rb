# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::SyncProductStocksJob do
  describe '#perform' do
    before do
      InsalesSetting.create!(
        base_url: 'https://example.myinsales.ru',
        login: 'user',
        password: 'pass',
        category_id: '777',
        allowed_store_names: ['Тест']
      )
    end

    it 'marks run as partial_success when only media verify warnings are present' do
      result = Insales::SyncProductStocks::Result.new(
        processed: 10,
        created: 2,
        updated: 8,
        errors: 0,
        variant_updates: 10,
        images_uploaded: 1,
        images_skipped: 0,
        images_errors: 0,
        videos_uploaded: 0,
        videos_skipped: 0,
        verify_failures: 3,
        last_http_status: 200,
        last_http_endpoint: '/admin/variants/1.json',
        last_error_message: 'processing: Admin images count 0 < expected 2'
      )

      service = instance_double(Insales::SyncProductStocks, call: result)
      allow(Insales::SyncProductStocks).to receive(:new).and_return(service)

      described_class.perform_now(store_names: ['Тест'])

      run = InsalesSyncRun.order(created_at: :desc).first
      state = InsalesStockSyncState.find_by(store_name: 'Тест')

      expect(run.status).to eq('partial_success')
      expect(run.error_count).to eq(0)
      expect(run.verify_failures).to eq(3)
      expect(state.last_status).to eq('partial_success')
      expect(state.verify_failures).to eq(3)
    end
  end
end
