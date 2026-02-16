# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::VerifyProduct do
  let(:base_url) { 'https://example.myinsales.ru' }
  let(:login) { 'user' }
  let(:password) { 'pass' }

  before do
    InsalesSetting.create!(
      base_url: base_url,
      login: login,
      password: password,
      category_id: '123',
      default_collection_id: '555',
      image_url_mode: 'service_url'
    )
  end

  it 'verifies product and variant' do
    product = create(:product, name: 'Test Product', sku: 'SKU-1000', retail_price: 12.5)
    create(:product_stock, product: product, stock: 3, store_name: 'Тест')

    stub_request(:get, "#{base_url}/admin/products/10.json")
      .with(basic_auth: [login, password])
      .to_return(
        status: 200,
        body: {
          product: {
            id: 10,
            title: 'Test Product',
            category_id: 123,
            collection_ids: [555],
            variants: [{ id: 55, sku: 'SKU-1000' }]
          }
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    stub_request(:get, "#{base_url}/admin/variants/55.json")
      .with(basic_auth: [login, password])
      .to_return(
        status: 200,
        body: { variant: { id: 55, sku: 'SKU-1000', price: 12.5, quantity: 3 } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = described_class.new.call(
      product: product,
      insales_product_id: 10,
      insales_variant_id: 55,
      expected_category_id: '123',
      expected_collection_id: '555'
    )

    expect(result.ok).to be(true)
  end
end
