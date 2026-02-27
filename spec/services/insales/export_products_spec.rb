# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::ExportProducts do
  describe '#build_payload' do
    it 'builds payload with catalog prices, quantity and properties' do
      product = create(:product, name: 'Payload Product', sku: 'SKU-2000', retail_price: 9.99)
      catalog_item = InsalesCatalogItem.create!(
        product: product,
        export_quantity: 11,
        prices_cents: {
          'retail' => 1234,
          'small_wholesale' => 1100,
          'big_wholesale' => 900
        },
        status: 'ready',
        prepared_at: Time.current
      )

      InsalesSetting.create!(
        base_url: 'https://example.myinsales.ru',
        login: 'user',
        password: 'pass',
        category_id: '777',
        default_collection_id: '999',
        image_url_mode: 'service_url',
        allowed_store_names: ['Тест']
      )

      service = described_class.new
      payload = service.send(
        :build_payload,
        product,
        collection_id: nil,
        properties_attributes: [{ title: 'Тип товара', value: 'Срезы' }],
        catalog_item: catalog_item
      )

      expect(payload[:product][:title]).to eq('Payload Product')
      expect(payload[:product][:category_id]).to eq(777)
      expect(payload[:product][:variants_attributes].first[:sku]).to eq('SKU-2000')
      expect(payload[:product][:variants_attributes].first[:price]).to eq(12.34)
      expect(payload[:product][:variants_attributes].first[:price2]).to eq(11.0)
      expect(payload[:product][:variants_attributes].first[:price3]).to eq(9.0)
      expect(payload[:product][:variants_attributes].first[:quantity]).to eq(11)
      expect(payload[:product][:properties_attributes]).to eq([{ title: 'Тип товара', value: 'Срезы' }])
      expect(payload[:product]).not_to have_key(:product_field_values_attributes)
    end
  end

  describe 'export with mapping' do
    let(:client) { instance_double(Insales::InsalesClient) }
    let(:properties_catalog) { instance_double(Insales::ProductPropertyCatalog) }

    before do
      InsalesSetting.create!(
        base_url: 'https://example.myinsales.ru',
        login: 'user',
        password: 'pass',
        category_id: '777',
        default_collection_id: '999',
        image_url_mode: 'service_url',
        allowed_store_names: ['A', 'B']
      )

      @previous_assign = ENV['INSALES_ASSIGN_COLLECTIONS']
      ENV['INSALES_ASSIGN_COLLECTIONS'] = '1'

      allow(Insales::ProductPropertyCatalog).to receive(:new).and_return(properties_catalog)
      allow(properties_catalog).to receive(:properties_attributes).and_return([
        { id: 77, title: 'Тип товара', value: 'Срезы' },
        { title: 'Омбре', value: 'Нет' }
      ])
    end

    after do
      ENV['INSALES_ASSIGN_COLLECTIONS'] = @previous_assign
    end

    it 'updates product, variant and uses catalog prices/qty with properties_attributes' do
      product = create(:product, name: 'Export Product', sku: 'SKU-1', retail_price: 12.5)
      create(:product_stock, product: product, stock: 99, store_name: 'A')
      create(:product_stock, product: product, stock: 99, store_name: 'B')
      InsalesCatalogItem.create!(
        product: product,
        export_quantity: 7,
        prices_cents: {
          'retail' => 4321,
          'small_wholesale' => 4000,
          'big_wholesale' => 3900
        },
        status: 'ready',
        prepared_at: Time.current
      )

      mapping = InsalesProductMapping.create!(
        aura_product_id: product.id,
        insales_product_id: 101,
        insales_variant_id: 202
      )

      allow(client).to receive(:get).with(
        "/admin/products/#{mapping.insales_product_id}.json"
      ).and_return(double(status: 200, body: {
        'product' => {
          'properties' => [
            { 'id' => 77, 'title' => 'Тип товара', 'characteristics' => ['Срезы'] },
            { 'id' => 90, 'title' => 'Чужое поле', 'characteristics' => ['X'] }
          ]
        }
      }))

      allow(client).to receive(:put).with(
        "/admin/products/#{mapping.insales_product_id}.json",
        anything
      ).and_return(double(status: 200, body: {}))

      allow(client).to receive(:put).with(
        "/admin/variants/#{mapping.insales_variant_id}.json",
        hash_including(variant: hash_including(price: 43.21, price2: 40.0, price3: 39.0, quantity: 7))
      ).and_return(double(status: 200, body: {}))

      allow(client).to receive(:collects_by_product).with(
        product_id: mapping.insales_product_id
      ).and_return(double(status: 200, body: []))

      allow(client).to receive(:collect_create).with(
        product_id: mapping.insales_product_id,
        collection_id: 999
      ).and_return(double(status: 200, body: {}))

      described_class.new(client).call(product_id: product.id, dry_run: false, collection_id: nil)

      expect(client).to have_received(:put).with(
        "/admin/products/#{mapping.insales_product_id}.json",
        satisfy do |payload|
          product_payload = payload[:product]
          product_payload[:properties_attributes].is_a?(Array) &&
            product_payload[:properties_attributes].size == 2 &&
            !product_payload.key?(:product_field_values_attributes)
        end
      )

      expect(client).to have_received(:put).with(
        "/admin/variants/#{mapping.insales_variant_id}.json",
        hash_including(variant: hash_including(price: 43.21, price2: 40.0, price3: 39.0, quantity: 7))
      )
    end

    it 'creates product and mapping when none exists' do
      product = create(:product, name: 'New Product', sku: 'SKU-NEW', retail_price: 7.0)
      create(:product_stock, product: product, stock: 1, store_name: 'A')
      InsalesCatalogItem.create!(
        product: product,
        export_quantity: 1,
        prices_cents: {
          'retail' => 700,
          'small_wholesale' => 650,
          'big_wholesale' => 600
        },
        status: 'ready',
        prepared_at: Time.current
      )

      allow(client).to receive(:post).with('/admin/products.json', anything).and_return(
        double(status: 201, body: { 'product' => { 'id' => 909, 'variants' => [{ 'id' => 808 }] } })
      )
      allow(client).to receive(:collects_by_product).with(
        product_id: 909
      ).and_return(double(status: 200, body: []))
      allow(client).to receive(:collect_create).with(
        product_id: 909,
        collection_id: 999
      ).and_return(double(status: 200, body: {}))

      result = described_class.new(client).call(product_id: product.id, dry_run: false, collection_id: nil)

      expect(result.created).to eq(1)
      mapping = InsalesProductMapping.find_by(aura_product_id: product.id)
      expect(mapping).not_to be_nil
      expect(mapping.insales_product_id).to eq(909)
      expect(mapping.insales_variant_id).to eq(808)
      expect(client).to have_received(:post).with('/admin/products.json', satisfy do |payload|
        product_payload = payload[:product]
        product_payload[:variants_attributes].first[:price2] == 6.5 &&
          product_payload[:variants_attributes].first[:price3] == 6.0 &&
          !product_payload.key?(:product_field_values_attributes)
      end)
    end

    it 'recreates mapping when existing InSales product is missing (404)' do
      product = create(:product, name: 'Stale Product', sku: 'SKU-STALE', retail_price: 5.0)
      create(:product_stock, product: product, stock: 2, store_name: 'A')
      InsalesCatalogItem.create!(
        product: product,
        export_quantity: 2,
        prices_cents: { 'retail' => 500 },
        status: 'ready',
        prepared_at: Time.current
      )

      mapping = InsalesProductMapping.create!(
        aura_product_id: product.id,
        insales_product_id: 101,
        insales_variant_id: 202
      )

      allow(client).to receive(:get).with(
        "/admin/products/#{mapping.insales_product_id}.json"
      ).and_return(double(status: 404, body: { 'message' => 'Not found' }))

      allow(client).to receive(:post).with('/admin/products.json', anything).and_return(
        double(status: 201, body: { 'product' => { 'id' => 909, 'variants' => [{ 'id' => 808 }] } })
      )
      allow(client).to receive(:collects_by_product).with(
        product_id: 909
      ).and_return(double(status: 200, body: []))
      allow(client).to receive(:collect_create).with(
        product_id: 909,
        collection_id: 999
      ).and_return(double(status: 200, body: {}))

      result = described_class.new(client).call(product_id: product.id, dry_run: false, collection_id: nil)

      expect(result.created).to eq(1)
      expect(InsalesProductMapping.find_by(aura_product_id: product.id).insales_product_id).to eq(909)
      expect(InsalesProductMapping.find_by(aura_product_id: product.id).insales_variant_id).to eq(808)
      expect(InsalesProductMapping.where(insales_product_id: 101)).to be_empty
    end
  end

  describe 'skip rules and catalog state' do
    let(:client) { instance_double(Insales::InsalesClient) }

    before do
      InsalesSetting.create!(
        base_url: 'https://example.myinsales.ru',
        login: 'user',
        password: 'pass',
        category_id: '777',
        default_collection_id: '999',
        image_url_mode: 'service_url',
        allowed_store_names: ['A']
      )

      allow(Insales::ProductPropertyCatalog).to receive(:new).and_return(instance_double(Insales::ProductPropertyCatalog, properties_attributes: []))
    end

    it 'skips products without sku when setting enabled' do
      product = create(:product, sku: nil, code: nil)
      create(:product_stock, product: product, stock: 5, store_name: 'A')
      InsalesSetting.first.update!(skip_products_without_sku: true)

      expect(client).not_to receive(:post)
      expect(client).not_to receive(:put)

      result = described_class.new(client).call(product_id: product.id, dry_run: false, collection_id: nil)

      expect(result.created).to eq(0)
      expect(result.updated).to eq(0)
      expect(result.errors).to eq(0)
    end

    it 'skips products with nonpositive stock when setting enabled' do
      product = create(:product, sku: 'SKU-ZERO')
      create(:product_stock, product: product, stock: 0, store_name: 'A')
      InsalesSetting.first.update!(skip_products_with_nonpositive_stock: true)

      expect(client).not_to receive(:post)
      expect(client).not_to receive(:put)

      result = described_class.new(client).call(product_id: product.id, dry_run: false, collection_id: nil)

      expect(result.created).to eq(0)
      expect(result.updated).to eq(0)
      expect(result.errors).to eq(0)
    end

    it 'returns catalog not prepared error when ready catalog item is missing' do
      product = create(:product, sku: 'SKU-CAT-1')
      create(:product_stock, product: product, stock: 5, store_name: 'A')

      expect(client).not_to receive(:post)
      expect(client).not_to receive(:put)

      result = described_class.new(client).call(product_id: product.id, dry_run: false, collection_id: nil)

      expect(result.processed).to eq(1)
      expect(result.created).to eq(0)
      expect(result.updated).to eq(0)
      expect(result.errors).to eq(1)
    end
  end
end
