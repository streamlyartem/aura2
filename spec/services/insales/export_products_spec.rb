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
