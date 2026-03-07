# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Moysklad::FindAndImportProductByBarcode do
  let(:client) { instance_double(MoyskladClient) }

  it 'finds product by barcode from MoySklad and upserts into AURA' do
    raw = '0099990001234'
    payload = {
      'id' => '11111111-2222-3333-4444-555555555555',
      'name' => 'Срезы Светлый 55/20',
      'article' => 'SCAN-99990001234',
      'code' => '99990001234',
      'barcodes' => [{ 'code128' => '0099990001234' }],
      'pathName' => 'Срезы/Светлый/55',
      'weight' => 114.0,
      'attributes' => [],
      'buyPrice' => { 'value' => 10_000.0 },
      'salePrices' => [{ 'value' => 17_000.0, 'priceType' => { 'name' => 'Цена продажи' } }],
      'minPrice' => { 'value' => 17_000.0 }
    }

    allow(client).to receive(:get_full)
      .with("entity/product?search=#{raw}&limit=100")
      .and_return(double(body: { 'rows' => [payload] }))

    product = described_class.new(client).call(raw_value: raw)

    expect(product).to be_present
    expect(product.ms_id).to eq('11111111-2222-3333-4444-555555555555')
    expect(product.sku).to eq('SCAN-99990001234')
    expect(product.retail_price.to_f).to eq(170.0)
  end

  it 'returns nil when product is not found in MoySklad' do
    allow(client).to receive(:get_full).and_return(double(body: { 'rows' => [] }))

    product = described_class.new(client).call(raw_value: '999999')

    expect(product).to be_nil
  end
end
