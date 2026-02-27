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
      image_url_mode: 'service_url',
      allowed_store_names: ['Тест']
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
      media_sync = instance_double(Insales::SyncProductMedia)
      allow(Insales::SyncProductMedia).to receive(:new).and_return(media_sync)
      allow(media_sync).to receive(:call).and_return(double(status: 'success', last_error: nil))
      allow(client).to receive(:put).and_return(double(status: 200, body: {}))

      result = service.call(product_id: product.id, reason: 'media_changed')

      expect(result.status).to eq('success')
      expect(result.action).to eq('publish')
      expect(Insales::ExportProducts).to have_received(:call).with(product_id: product.id, dry_run: false)
      expect(client).to have_received(:put).with(
        "/admin/products/#{mapping.insales_product_id}.json",
        { product: { is_hidden: false } }
      )
      expect(media_sync).to have_received(:call)
    end

    it 'unpublishes when product is sold out' do
      create(:product_stock, product: product, stock: 0, store_name: 'Тест')
      create(:image, object: product)
      mapping = InsalesProductMapping.create!(aura_product_id: product.id, insales_product_id: 123, insales_variant_id: 456)

      allow(Insales::ExportProducts).to receive(:call).and_return(double(errors: 0))
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
      expect(Insales::SyncProductMedia).not_to receive(:new)
      allow(client).to receive(:put).and_return(double(status: 200, body: {}))

      result = service.call(product_id: product.id, reason: 'stock_changed')

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

      allow(Insales::ExportProducts).to receive(:call).and_return(double(errors: 0))
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


    it 'publishes when free stock exists even if stock is zero' do
      create(:product_stock, product: product, stock: 0, free_stock: 1, store_name: 'Тест')
      mapping = InsalesProductMapping.create!(aura_product_id: product.id, insales_product_id: 555, insales_variant_id: 666)

      allow(Insales::ExportProducts).to receive(:call).and_return(double(errors: 0))
      allow(client).to receive(:put).and_return(double(status: 200, body: {}))

      result = service.call(product_id: product.id, reason: 'stock_changed')

      expect(result.status).to eq('success')
      expect(result.action).to eq('publish')
      expect(client).to have_received(:put).with(
        "/admin/products/#{mapping.insales_product_id}.json",
        { product: { is_hidden: false } }
      )
    end

    it 'ignores stock from other stores' do
      create(:product_stock, product: product, stock: 5, store_name: 'Другой склад')
      mapping = InsalesProductMapping.create!(aura_product_id: product.id, insales_product_id: 321, insales_variant_id: 456)

      allow(Insales::ExportProducts).to receive(:call).and_return(double(errors: 0))
      allow(client).to receive(:put).and_return(double(status: 200, body: {}))

      result = service.call(product_id: product.id, reason: 'stock_changed')

      expect(result.status).to eq('success')
      expect(result.action).to eq('unpublish')
      expect(client).to have_received(:put).with(
        "/admin/products/#{mapping.insales_product_id}.json",
        { product: { collection_ids: [], is_hidden: true } }
      )
    end

    it 'returns error when export has errors' do
      create(:product_stock, product: product, stock: 1, store_name: 'Тест')
      InsalesProductMapping.create!(aura_product_id: product.id, insales_product_id: 222, insales_variant_id: 333)

      allow(Insales::ExportProducts).to receive(:call).and_return(double(errors: 1))
      expect(Insales::SyncProductMedia).not_to receive(:new)
      allow(client).to receive(:put).and_return(double(status: 200, body: {}))

      result = service.call(product_id: product.id, reason: 'product_changed')

      expect(result.status).to eq('error')
      expect(result.action).to eq('publish')
      expect(result.message).to include('Export errors=1')
    end

    it 'returns error when unpublish fails' do
      create(:product_stock, product: product, stock: 0, store_name: 'Тест')
      mapping = InsalesProductMapping.create!(aura_product_id: product.id, insales_product_id: 999, insales_variant_id: 888)

      allow(Insales::ExportProducts).to receive(:call).and_return(double(errors: 0))
      allow(client).to receive(:put).and_return(double(status: 500, body: {}))

      result = service.call(product_id: product.id, reason: 'stock_changed')

      expect(result.status).to eq('error')
      expect(result.action).to eq('unpublish')
      expect(result.message).to eq('HTTP 500')
      expect(client).to have_received(:put).with(
        "/admin/products/#{mapping.insales_product_id}.json",
        { product: { collection_ids: [], is_hidden: true } }
      )
    end

    it 'returns error when unpublish export has errors' do
      create(:product_stock, product: product, stock: 0, store_name: 'Тест')
      mapping = InsalesProductMapping.create!(aura_product_id: product.id, insales_product_id: 1001, insales_variant_id: 1002)

      allow(Insales::ExportProducts).to receive(:call).and_return(double(errors: 2))
      allow(client).to receive(:put).and_return(double(status: 200, body: {}))

      result = service.call(product_id: product.id, reason: 'stock_changed')

      expect(result.status).to eq('error')
      expect(result.action).to eq('unpublish')
      expect(result.message).to include('Export errors=2')
      expect(client).to have_received(:put).with(
        "/admin/products/#{mapping.insales_product_id}.json",
        { product: { collection_ids: [], is_hidden: true } }
      )
    end
  end
end
