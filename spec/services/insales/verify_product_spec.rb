# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::VerifyProduct do
  let(:client) { instance_double(Insales::InsalesClient) }
  let(:product) { create(:product, sku: 'SKU-1', retail_price: 123.456) }

  before do
    InsalesSetting.create!(
      base_url: 'https://example.myinsales.ru',
      login: 'login',
      password: 'password',
      category_id: 1,
      allowed_store_names: ['Тест']
    )
    create(:product_stock, product: product, store_name: 'Тест', stock: 10)
    create(:product_stock, product: product, store_name: 'Другой', stock: 99)
  end

  it 'verifies using allowed stores stock only and rounded price' do
    product_response = {
      'product' => {
        'title' => product.name,
        'category_id' => nil,
        'collection_ids' => [],
        'variants' => [{ 'id' => 55, 'sku' => product.sku }]
      }
    }
    variant_response = {
      'variant' => {
        'id' => 55,
        'sku' => product.sku,
        'price' => 123.46,
        'quantity' => 10
      }
    }

    allow(client).to receive(:get)
      .with('/admin/products/1.json')
      .and_return(double(status: 200, body: product_response))
    allow(client).to receive(:get)
      .with('/admin/variants/55.json')
      .and_return(double(status: 200, body: variant_response))

    result = described_class.new(client).call(product: product, insales_product_id: 1, insales_variant_id: 55)

    expect(result.ok).to be(true)
  end

  it 'uses explicit expected price and quantity when provided' do
    product_response = {
      'product' => {
        'title' => product.name,
        'category_id' => nil,
        'collection_ids' => [],
        'variants' => [{ 'id' => 55, 'sku' => product.sku }]
      }
    }
    variant_response = {
      'variant' => {
        'id' => 55,
        'sku' => product.sku,
        'price' => 19.0,
        'quantity' => 1
      }
    }

    allow(client).to receive(:get)
      .with('/admin/products/1.json')
      .and_return(double(status: 200, body: product_response))
    allow(client).to receive(:get)
      .with('/admin/variants/55.json')
      .and_return(double(status: 200, body: variant_response))

    result = described_class.new(client).call(
      product: product,
      insales_product_id: 1,
      insales_variant_id: 55,
      expected_price: 19.0,
      expected_quantity: 1
    )

    expect(result.ok).to be(true)
  end
end
