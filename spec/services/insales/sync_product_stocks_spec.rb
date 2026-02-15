# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::SyncProductStocks do
  let(:base_url) { 'https://example.myinsales.ru' }
  let(:login) { 'user' }
  let(:password) { 'pass' }

  before do
    InsalesSetting.create!(
      base_url: base_url,
      login: login,
      password: password,
      category_id: '777',
      default_collection_id: '999',
      image_url_mode: 'service_url'
    )
  end

  it 'syncs one product and verifies' do
    product = create(:product, name: 'Sync Product', sku: 'SKU-3000', retail_price: 19.0)
    create(:product_stock, product: product, stock: 2, store_name: 'Тест')
    InsalesProductMapping.create!(
      aura_product_id: product.id,
      insales_product_id: 10,
      insales_variant_id: 55
    )

    stub_request(:put, "#{base_url}/admin/products/10.json")
      .with(basic_auth: [login, password])
      .to_return(status: 200, body: { product: { id: 10 } }.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:put, "#{base_url}/admin/variants/55.json")
      .with(basic_auth: [login, password])
      .to_return(status: 200, body: { variant: { id: 55 } }.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:post, "#{base_url}/admin/collections/999/products.json")
      .with(basic_auth: [login, password])
      .to_return(status: 200, body: {}.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:put, "#{base_url}/admin/products/variants_group_update.json")
      .with(basic_auth: [login, password])
      .to_return(status: 200, body: {}.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:get, "#{base_url}/admin/products/10.json")
      .with(basic_auth: [login, password])
      .to_return(
        status: 200,
        body: {
          product: {
            id: 10,
            title: 'Sync Product',
            category_id: 777,
            collection_ids: [999],
            variants: [{ id: 55, sku: 'SKU-3000' }]
          }
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    stub_request(:get, "#{base_url}/admin/variants/55.json")
      .with(basic_auth: [login, password])
      .to_return(
        status: 200,
        body: { variant: { id: 55, sku: 'SKU-3000', price: 19.0, quantity: 2 } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = described_class.new.call(store_name: 'Тест')

    expect(result.processed).to eq(1)
    expect(result.errors).to eq(0)
    expect(result.verify_failures).to eq(0)
  end
end
