# frozen_string_literal: true

require 'rails_helper'
require 'services/concerns/moysklad_shared_contexts'

RSpec.describe MoyskladSync do
  describe '#import_products' do
    subject(:import_products) { described_class.new.import_products }

    include_context 'with moysklad products mock'

    context "when products don't exist yet" do
      let(:sku) { '1905432613387' } # from fixture
      let(:ms_id) { '00006cfc-8285-11f0-0a80-112a0007f611' }

      it 'creates products with proper attributes' do
        expect { import_products }.to change(Product, :count).by(2)

        expect(Product.find_by(ms_id: ms_id)).to have_attributes(
          ms_id: ms_id,
          name: 'Срезы Темный 55/2',
          batch_number: 'Партия 2498',
          path_name: 'Срезы/Темный/55',
          weight: 110.0,
          length: 55.0,
          color: '2',
          tone: 'Темный',
          ombre: false,
          structure: 'Прямой',
          sku: sku,
          code: sku,
          barcodes: [{ 'code128' => '1905432613387' }, { 'ean13' => '2000000337920' }],
          purchase_price: 118.35,
          retail_price: 180.0,
          small_wholesale_price: 162.0,
          large_wholesale_price: 144.0,
          five_hundred_plus_wholesale_price: 126.0,
          min_price: 126.0
        )
      end
    end

    context 'when product missing article or non-positive weight' do
      it 'skips such products' do
        bad_payloads = [
          { 'id' => 'skip-1', 'name' => 'No Article', 'article' => nil, 'pathName' => 'Срезы/Светлый/55', 'weight' => 10, 'attributes' => [], 'salePrices' => [], 'buyPrice' => { 'value' => 0 }, 'minPrice' => { 'value' => 0 } },
          { 'id' => 'skip-2', 'name' => 'Zero Weight', 'article' => 'SKU-ZERO', 'pathName' => 'Срезы/Светлый/55', 'weight' => 0, 'attributes' => [], 'salePrices' => [], 'buyPrice' => { 'value' => 0 }, 'minPrice' => { 'value' => 0 } }
        ]

        allow_any_instance_of(MoyskladClient).to receive(:each_product) do |_, &block|
          bad_payloads.each(&block)
        end

        expect { import_products }.not_to change(Product, :count)
      end
    end

    context 'when some products already exist' do
      let!(:existing_product) { create(:product, ms_id: '00006cfc-8285-11f0-0a80-112a0007f611', sku: '1905432613387', name: 'Old Name') }

      it 'creates only one product' do
        expect { import_products }.to change(Product, :count).by(1)
      end

      it 'updates existing product name by ms_id' do
        expect { import_products }.to change { existing_product.reload.name }.from('Old Name').to('Срезы Темный 55/2')
      end
    end
  end

  describe '#import_stocks' do
    subject(:import_products) { described_class.new.import_stocks }

    include_context 'with moysklad stocks mock'

    context 'when matching products exist' do
      let!(:product_one) { create(:product, ms_id: 'e91210f9-9166-11f0-0a80-0ef200165e2f', weight: 0) } # from fixture
      let!(:product_two) { create(:product, ms_id: '2fdc2bec-9166-11f0-0a80-0ef200164c50', weight: 0) } # from fixture

      before do
        product_one
        product_two
      end

      it 'creates only one product' do
        expect { import_products }.to change(ProductStock, :count).by(2)
      end

      it 'keeps product weight equal to imported stock value' do
        import_products

        expect(product_one.reload.weight.to_f).to eq(102.0)
        expect(product_two.reload.weight.to_f).to eq(86.0)
      end
    end

    context 'when matching products do not exist' do
      it 'creates only one product' do
        expect { import_products }.not_to change(ProductStock, :count)
      end
    end
  end
end
