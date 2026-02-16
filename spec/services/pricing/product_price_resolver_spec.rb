# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pricing::ProductPriceResolver do
  subject(:resolver) { described_class.new }

  let(:srezy_product) do
    create(
      :product,
      path_name: 'Срезы/Светлый/40',
      retail_price: 120,
      small_wholesale_price: 108,
      large_wholesale_price: 99
    )
  end

  let(:other_product) do
    create(
      :product,
      path_name: 'Трессы/Светлый/40',
      retail_price: 200,
      small_wholesale_price: 150,
      large_wholesale_price: 130
    )
  end

  it 'uses retail price for srezy below 500g' do
    result = resolver.call(product: srezy_product, quantity_g: 499)

    expect(result.tier).to eq('retail')
    expect(result.unit_price).to eq(120.0)
    expect(result.total_price).to eq(120.0 * 499)
  end

  it 'uses small wholesale for srezy from 500g to 999g' do
    result = resolver.call(product: srezy_product, quantity_g: 750)

    expect(result.tier).to eq('small_wholesale')
    expect(result.unit_price).to eq(108.0)
  end

  it 'uses large wholesale for srezy from 1000g' do
    result = resolver.call(product: srezy_product, quantity_g: 1000)

    expect(result.tier).to eq('large_wholesale')
    expect(result.unit_price).to eq(99.0)
  end

  it 'always uses retail for non-srezy products' do
    result = resolver.call(product: other_product, quantity_g: 2000)

    expect(result.tier).to eq('retail')
    expect(result.unit_price).to eq(200.0)
  end
end
