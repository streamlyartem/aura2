# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Moysklad::Product do
  it 'normalizes money fields from MoySklad minor units' do
    payload = {
      'id' => 'ms-1',
      'name' => 'Test Product',
      'article' => 'SKU-1',
      'code' => 'CODE-1',
      'pathName' => 'Срезы/Светлый/55',
      'weight' => 99,
      'attributes' => [],
      'buyPrice' => { 'value' => 12_345 },
      'minPrice' => { 'value' => 17_500 },
      'salePrices' => [
        { 'value' => 17_500, 'priceType' => { 'name' => 'Цена продажи' } },
        { 'value' => 16_200, 'priceType' => { 'name' => 'мелкий опт' } },
        { 'value' => 14_400, 'priceType' => { 'name' => 'крупный опт' } },
        { 'value' => 12_600, 'priceType' => { 'name' => 'Опт 500+' } }
      ]
    }

    product = described_class.new(payload)

    expect(product.purchase_price).to eq(123.45)
    expect(product.retail_price).to eq(175.0)
    expect(product.small_wholesale_price).to eq(162.0)
    expect(product.large_wholesale_price).to eq(144.0)
    expect(product.five_hundred_plus_wholesale_price).to eq(126.0)
    expect(product.min_price).to eq(175.0)
  end
end
