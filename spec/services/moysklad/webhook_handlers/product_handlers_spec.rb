# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Moysklad product webhook handlers' do
  include ActiveJob::TestHelper

  before do
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
  end

  let(:event) do
    {
      'meta' => { 'type' => 'product', 'href' => 'https://api.moysklad.ru/api/remap/1.2/entity/product/abc' },
      'action' => action
    }
  end

  let(:payload) do
    {
      'id' => 'ms-123',
      'name' => 'Hair Bundle',
      'article' => 'SKU-123',
      'code' => 'CODE-1',
      'pathName' => 'hair/bundle',
      'weight' => 100,
      'barcodes' => [],
      'attributes' => [
        { 'name' => 'Омбре', 'value' => 'нет' },
        { 'name' => 'Длина', 'value' => '50' },
        { 'name' => 'Цвет', 'value' => 'natural' },
        { 'name' => 'Тон', 'value' => { 'name' => '7' } },
        { 'name' => 'Структура', 'value' => { 'name' => 'прямой' } }
      ],
      'salePrices' => [],
      'buyPrice' => { 'value' => 0 },
      'minPrice' => { 'value' => 0 }
    }
  end

  describe Moysklad::WebhookHandlers::ProductCreateHandler do
    let(:action) { 'CREATE' }

    it 'creates product and enqueues insales trigger job' do
      handler = described_class.new(event)
      allow(handler).to receive(:fetch_entity_data).and_return(payload)

      expect do
        handler.handle
      end.to change(Product, :count).by(1).and change { enqueued_jobs.size }.by(1)

      created = Product.last
      expect(enqueued_jobs.last[:job]).to eq(Insales::SyncProductTriggerJob)
      expect(enqueued_jobs.last.dig(:args, 0, 'reason')).to eq('product_changed')
      expect(created.name).to eq('Hair Bundle')
      expect(created.structure).to eq('прямой')
    end
  end

  describe Moysklad::WebhookHandlers::ProductUpdateHandler do
    let(:action) { 'UPDATE' }

    it 'updates product, syncs stock from weight and enqueues trigger jobs' do
      product = create(:product, sku: payload['article'], name: 'Old name')
      handler = described_class.new(event)
      allow(handler).to receive(:fetch_entity_data).and_return(
        payload.merge('id' => product.ms_id, 'name' => 'New name')
      )

      expect { handler.handle }.to change { enqueued_jobs.size }.by(2)
      reasons = enqueued_jobs
                .select { |job| job[:job] == Insales::SyncProductTriggerJob }
                .map { |job| job.dig(:args, 0, 'reason') }

      expect(reasons).to include('product_changed', 'stock_changed')

      expect(product.reload.name).to eq('New name')
      expect(product.reload.structure).to eq('прямой')
      stock = ProductStock.find_by(product_id: product.id, store_name: MoyskladClient::TEST_STORE_NAME)
      expect(stock.stock.to_f).to eq(100.0)
      expect(product.reload.weight.to_f).to eq(100.0)
    end
  end
end
