# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::SyncProductTrigger do
  let(:client) { instance_double(Insales::InsalesClient) }
  let(:service) { described_class.new(client) }
  let(:product) { create(:product, name: 'Hair Product', sku: 'SKU-1') }

  before do
    InsalesSetting.create!(
      base_url: 'https://example.myinsales.ru',
      login: 'login',
      password: 'password',
      category_id: '1',
      default_collection_id: '2',
      image_url_mode: 'service_url'
    )
  end

  describe '#call' do
    it 'publishes when product has stock and media' do
      create(:product_stock, product: product, stock: 2, store_name: 'Тест')
      create(:image, object: product)
      mapping = InsalesProductMapping.create!(
        aura_product_id: product.id,
        insales_product_id: 111,
        insales_variant_id: 222
      )

      allow(Insales::ExportProducts).to receive(:call).and_return(double(errors: 0))
      media_result = double(status: 'success', last_error: nil)
      allow_any_instance_of(Insales::SyncProductMedia).to receive(:call).and_return(media_result)
      allow(client).to receive(:put).and_return(double(status: 200, body: {}))

      result = service.call(product_id: product.id, reason: 'test')

      expect(result.status).to eq('success')
      expect(result.action).to eq('publish')
      expect(Insales::ExportProducts).to have_received(:call).with(product_id: product.id, dry_run: false)
      expect(client).to have_received(:put).with(
        "/admin/products/#{mapping.insales_product_id}.json",
        { product: { is_hidden: false } }
      )
    end

    it 'unpublishes when product is sold out' do
      create(:product_stock, product: product, stock: 0, store_name: 'Тест')
      create(:image, object: product)
      mapping = InsalesProductMapping.create!(aura_product_id: product.id, insales_product_id: 123, insales_variant_id: 456)

      allow(client).to receive(:put).and_return(double(status: 200, body: {}))

      result = service.call(product_id: product.id, reason: 'stock_changed')

      expect(result.status).to eq('success')
      expect(result.action).to eq('unpublish')
      expect(client).to have_received(:put).with(
        "/admin/products/#{mapping.insales_product_id}.json",
        { product: { collection_ids: [], is_hidden: true } }
      )
    end

    it 'keeps product published when stock exists even without media' do
      create(:product_stock, product: product, stock: 3, store_name: 'Тест')
      mapping = InsalesProductMapping.create!(aura_product_id: product.id, insales_product_id: 321, insales_variant_id: 456)
      allow(Insales::ExportProducts).to receive(:call).and_return(double(errors: 0))
      media_result = double(status: 'success', last_error: nil)
      allow_any_instance_of(Insales::SyncProductMedia).to receive(:call).and_return(media_result)
      allow(client).to receive(:put).and_return(double(status: 200, body: {}))

      result = service.call(product_id: product.id, reason: 'media_changed')

      expect(result.status).to eq('success')
      expect(result.action).to eq('publish')
      expect(client).to have_received(:put).with(
        "/admin/products/#{mapping.insales_product_id}.json",
        { product: { is_hidden: false } }
      )
    end

    it 'retries unpublish without is_hidden when field is rejected' do
      create(:product_stock, product: product, stock: 0, store_name: 'Тест')
      create(:image, object: product)
      mapping = InsalesProductMapping.create!(aura_product_id: product.id, insales_product_id: 987, insales_variant_id: 654)

      allow(client).to receive(:put).and_return(
        double(status: 422, body: { errors: { is_hidden: ['unknown'] } }),
        double(status: 200, body: {})
      )

      result = service.call(product_id: product.id, reason: 'stock_changed')

      expect(result.status).to eq('success')
      expect(client).to have_received(:put).with(
        "/admin/products/#{mapping.insales_product_id}.json",
        { product: { collection_ids: [], is_hidden: true } }
      )
      expect(client).to have_received(:put).with(
        "/admin/products/#{mapping.insales_product_id}.json",
        { product: { collection_ids: [] } }
      )
    end
  end
end
