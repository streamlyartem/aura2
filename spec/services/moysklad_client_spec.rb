# frozen_string_literal: true

require 'rails_helper'
require 'services/concerns/moysklad_shared_contexts'

RSpec.describe MoyskladClient do
  let(:service) { described_class.new(username: 'user', password: 'pass') }

  describe '#product' do
    subject(:product) { service.product(ms_id) }

    let(:ms_id) { SecureRandom.uuid }
    let(:parsed_product) { JSON.parse(product_json.read) }

    context 'when product found' do
      include_context 'with moysklad get product mock' do
        let(:id_to_stub) { ms_id }
      end

      it 'performs GET to entity/product/:id and returns response' do
        expect(product).to eq(parsed_product)
      end
    end

    context 'when product not found' do
      let(:parsed_error) { JSON.parse(product_not_found_json.read) }

      include_context 'with moysklad get product mock' do
        let(:id_to_stub) { SecureRandom.uuid }
      end

      it 'performs GET to entity/product/:id and returns error response' do
        expect(product).to eq(parsed_error)
      end
    end
  end

  describe '#each_product' do
    include_context 'with moysklad products mock'

    let(:ms_rows) { JSON.parse(products_json.read)['rows'] }

    it 'yields all products from paginated responses' do
      yielded = []
      service.each_product { |row| yielded << row }

      expect(yielded).to eq(ms_rows)
    end

    it 'returns an enumerator when no block given' do
      enumerator = service.each_product
      expect(enumerator).to be_a(Enumerator)

      yielded = enumerator.to_a
      expect(yielded).to eq(ms_rows)
    end
  end

  describe '#stocks_for_store' do
    include_context 'with moysklad stocks mock'

    let(:stock_rows) { JSON.parse(stocks_filtered_by_store_json.read)['rows'] }

    it 'returns stocks for the store' do
      expect(service.stocks_for_store).to eq(stock_rows.map do |row|
        product_meta = row['meta']
        {
          code: row['code'],
          article: row['article'],
          stock: row['stock'],
          free_stock: row['freeStock'],
          reserve: row['reserve'],
          product_meta: product_meta,
          store_name: MoyskladClient::TEST_STORE_NAME
        }
      end)
    end
  end

  describe '#create_demand' do
    include_context 'with moysklad demand mock'

    let(:product) { create(:product) }
    let(:product_stock) { create(:product_stock, product: product) }
    let(:parsed_demand_response) { JSON.parse(demand_json.read) }

    it 'creates a demand' do
      response = service.create_demand(product, product_stock.stock)
      expect(response.body).to eq(parsed_demand_response)
    end
  end
end
