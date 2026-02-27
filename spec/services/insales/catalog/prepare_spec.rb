# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::Catalog::Prepare do
  let!(:setting) { create(:insales_setting, allowed_store_names: ['Тест']) }

  describe '.call' do
    it 'recalculates only selected product_ids when filter is provided' do
      target = create(:product, unit_type: 'weight', weight: 100, retail_price: 100, sku: 'TARGET')
      other = create(:product, unit_type: 'weight', weight: 100, retail_price: 100, sku: 'OTHER')
      create(:product_stock, product: target, store_name: 'Тест', stock: 10)
      create(:product_stock, product: other, store_name: 'Тест', stock: 10)

      described_class.call(product_ids: [target.id], export_updated_at: Time.current)

      expect(InsalesCatalogItem.find_by(product_id: target.id)).to be_present
      expect(InsalesCatalogItem.find_by(product_id: other.id)).to be_nil
    end

    it 'calculates weight item prices in cents from per-gram prices' do
      product = create(
        :product,
        unit_type: 'weight',
        weight: 106,
        retail_price: 175.0,
        small_wholesale_price: 163.0,
        large_wholesale_price: 150.0,
        five_hundred_plus_wholesale_price: 140.0
      )
      create(:product_stock, product: product, store_name: 'Тест', stock: 99)

      described_class.call
      item = InsalesCatalogItem.find_by!(product_id: product.id)

      expect(item.status).to eq('ready')
      expect(item.export_quantity).to eq(1)
      expect(item.prices_cents['retail']).to eq(1_855_000)
      expect(item.prices_cents['small_wholesale']).to eq(1_727_800)
    end

    it 'sets export_quantity for weight products to 1 only when stock is positive' do
      positive = create(:product, unit_type: 'weight', weight: 100, retail_price: 100, sku: 'POS')
      zero = create(:product, unit_type: 'weight', weight: 100, retail_price: 100, sku: 'ZERO')

      create(:product_stock, product: positive, store_name: 'Тест', stock: 1)
      create(:product_stock, product: zero, store_name: 'Тест', stock: 0)

      described_class.call

      expect(InsalesCatalogItem.find_by!(product_id: positive.id).export_quantity).to eq(1)
      expect(InsalesCatalogItem.find_by!(product_id: zero.id).export_quantity).to eq(0)
    end

    it 'skips products without sku when skip setting is enabled' do
      setting.update!(skip_products_without_sku: true)
      product = create(:product, sku: nil, code: nil, unit_type: 'weight', weight: 100, retail_price: 100)
      create(:product_stock, product: product, store_name: 'Тест', stock: 10)

      described_class.call
      item = InsalesCatalogItem.find_by!(product_id: product.id)

      expect(item.status).to eq('skipped')
      expect(item.skip_reason).to eq('no_sku')
    end

    it 'skips products with nonpositive stock when skip setting is enabled' do
      setting.update!(skip_products_with_nonpositive_stock: true)
      product = create(:product, unit_type: 'weight', weight: 100, retail_price: 100, sku: 'W-1')
      create(:product_stock, product: product, store_name: 'Тест', stock: 0)

      described_class.call
      item = InsalesCatalogItem.find_by!(product_id: product.id)

      expect(item.status).to eq('skipped')
      expect(item.skip_reason).to eq('nonpositive_stock')
    end
  end
end
