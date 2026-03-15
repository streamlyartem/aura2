# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::ApiV1::UpsertBatchRunner do
  describe '#call' do
    let(:run) { create(:insales_api_sync_run, status: 'queued') }

    it 'creates new product from valid item' do
      external_id = SecureRandom.uuid
      item = {
        external_id: external_id,
        sku: 'SKU-API-100',
        name: 'New product',
        updated_at: Time.current.iso8601,
        currency: 'RUB',
        price_minor: 15_500,
        stock_qty: 3
      }

      described_class.new.call(run: run, items: [item])

      run.reload
      expect(run.status).to eq('success')
      expect(run.created_count).to eq(1)

      product = Product.find_by(sku: 'SKU-API-100')
      expect(product).to be_present
      expect(product.retail_price.to_d).to eq(155)
      expect(ProductStock.find_by(product_id: product.id, store_name: 'API v1').stock.to_i).to eq(3)
    end

    it 'marks invalid item as skipped' do
      described_class.new.call(run: run, items: [{ sku: 'X' }])

      run.reload
      expect(run.skipped_count).to eq(1)
      expect(run.error_items.first['code']).to eq('VALIDATION_ERROR')
    end

    it 'returns unchanged when payload did not change' do
      product = create(:product, sku: 'SKU-UNCHANGED', retail_price: 100)
      create(:product_stock, product: product, store_name: 'API v1', stock: 2)

      item = {
        external_id: product.id,
        sku: 'SKU-UNCHANGED',
        name: product.name,
        updated_at: Time.current.iso8601,
        currency: 'RUB',
        price_minor: 10_000,
        stock_qty: 2
      }

      described_class.new.call(run: run, items: [item])

      run.reload
      expect(run.unchanged_count).to eq(1)
    end
  end
end
