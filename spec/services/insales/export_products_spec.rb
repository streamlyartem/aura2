# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::ExportProducts do
  let(:client) { instance_double(Insales::InsalesClient) }
  subject(:service) { described_class.new(client) }

  describe '#build_payload' do
    it 'builds payload with sku fallback, category_id, price and quantity' do
      product = create(:product, name: 'Test product', sku: nil, code: 'CODE-1', retail_price: 12.5)
      create(:product_stock, product: product, stock: 2)
      create(:product_stock, product: product, stock: 3)

      old_category = ENV['INSALES_CATEGORY_ID']
      ENV['INSALES_CATEGORY_ID'] = '123'

      payload = service.send(:build_payload, product)

      expect(payload[:product][:title]).to eq('Test product')
      expect(payload[:product][:category_id]).to eq(123)
      expect(payload[:product][:variants_attributes][0][:sku]).to eq('CODE-1')
      expect(payload[:product][:variants_attributes][0][:price]).to eq(12.5)
      expect(payload[:product][:variants_attributes][0][:quantity]).to eq(5.0)
    ensure
      ENV['INSALES_CATEGORY_ID'] = old_category
    end
  end

  describe '#total_stock' do
    it 'sums ProductStock.stock for a product' do
      product = create(:product)
      create(:product_stock, product: product, stock: 1.5)
      create(:product_stock, product: product, stock: 2.25)

      total = service.send(:total_stock, product)

      expect(total).to eq(3.75)
    end
  end
end
