# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::ExportProducts do
  it 'builds payload with sku, price, quantity' do
    product = create(:product, name: 'Payload Product', sku: 'SKU-2000', retail_price: 9.99)
    create(:product_stock, product: product, stock: 5, store_name: 'Тест')

    InsalesSetting.create!(
      base_url: 'https://example.myinsales.ru',
      login: 'user',
      password: 'pass',
      category_id: '777',
      default_collection_id: '999',
      image_url_mode: 'service_url'
    )

    service = described_class.new
    payload = service.send(:build_payload, product, collection_id: nil, product_field_values: [{ product_field_id: 1, value: 'X' }])

    expect(payload[:product][:title]).to eq('Payload Product')
    expect(payload[:product][:category_id]).to eq(777)
    expect(payload[:product][:variants_attributes].first[:sku]).to eq('SKU-2000')
    expect(payload[:product][:variants_attributes].first[:price]).to eq(9.99)
    expect(payload[:product][:variants_attributes].first[:quantity]).to eq(5.0)
    expect(payload[:product][:product_field_values_attributes]).to eq([{ product_field_id: 1, value: 'X' }])
  end
end

RSpec.describe Insales::ExportProducts do
  describe 'export with mapping' do
    let(:client) { instance_double(Insales::InsalesClient) }
    let(:catalog) { instance_double(Insales::ProductFieldCatalog) }

    before do
      InsalesSetting.create!(
        base_url: 'https://example.myinsales.ru',
        login: 'user',
        password: 'pass',
        category_id: '777',
        default_collection_id: '999',
        image_url_mode: 'service_url'
      )

      @previous_export_fields = ENV['INSALES_EXPORT_PRODUCT_FIELDS']
      @previous_assign = ENV['INSALES_ASSIGN_COLLECTIONS']
      ENV['INSALES_EXPORT_PRODUCT_FIELDS'] = '1'
      ENV['INSALES_ASSIGN_COLLECTIONS'] = '1'

      allow(Insales::ProductFieldCatalog).to receive(:new).with(client).and_return(catalog)
      allow(catalog).to receive(:product_field_values_attributes).and_return([
        { product_field_id: 42, value: 'X' }
      ])
    end

    after do
      ENV['INSALES_EXPORT_PRODUCT_FIELDS'] = @previous_export_fields
      ENV['INSALES_ASSIGN_COLLECTIONS'] = @previous_assign
    end

    it 'updates product, variant and includes product fields' do
      product = create(:product, name: 'Export Product', sku: 'SKU-1', retail_price: 12.5)
      create(:product_stock, product: product, stock: 2, store_name: 'A')
      create(:product_stock, product: product, stock: 3, store_name: 'B')

      mapping = InsalesProductMapping.create!(
        aura_product_id: product.id,
        insales_product_id: 101,
        insales_variant_id: 202
      )

      allow(client).to receive(:put).with(
        "/admin/products/#{mapping.insales_product_id}.json",
        hash_including(product: hash_including(product_field_values_attributes: [{ product_field_id: 42, value: 'X' }]))
      ).and_return(double(status: 200, body: {}))

      allow(client).to receive(:put).with(
        "/admin/variants/#{mapping.insales_variant_id}.json",
        hash_including(variant: hash_including(quantity: 5.0))
      ).and_return(double(status: 200, body: {}))

      allow(client).to receive(:post).with(
        "/admin/collections/999/products.json",
        { product_id: mapping.insales_product_id }
      ).and_return(double(status: 200, body: {}))

      described_class.new(client).call(product_id: product.id, dry_run: false, collection_id: nil)

      expect(client).to have_received(:put).with(
        "/admin/products/#{mapping.insales_product_id}.json",
        hash_including(product: hash_including(product_field_values_attributes: [{ product_field_id: 42, value: 'X' }]))
      )
      expect(client).to have_received(:put).with(
        "/admin/variants/#{mapping.insales_variant_id}.json",
        hash_including(variant: hash_including(quantity: 5.0))
      )
    end

    it 'creates product and mapping when none exists' do
      product = create(:product, name: 'New Product', sku: 'SKU-NEW', retail_price: 7.0)
      create(:product_stock, product: product, stock: 1, store_name: 'A')

      allow(client).to receive(:post).with('/admin/products.json', anything).and_return(
        double(status: 201, body: { 'product' => { 'id' => 909, 'variants' => [{ 'id' => 808 }] } })
      )
      allow(client).to receive(:post).with(
        "/admin/collections/999/products.json",
        { product_id: 909 }
      ).and_return(double(status: 200, body: {}))

      result = described_class.new(client).call(product_id: product.id, dry_run: false, collection_id: nil)

      expect(result.created).to eq(1)
      mapping = InsalesProductMapping.find_by(aura_product_id: product.id)
      expect(mapping).not_to be_nil
      expect(mapping.insales_product_id).to eq(909)
      expect(mapping.insales_variant_id).to eq(808)
    end
  end
end
