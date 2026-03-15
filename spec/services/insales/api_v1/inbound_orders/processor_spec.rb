# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::ApiV1::InboundOrders::Processor do
  let(:processor) { described_class.new }

  it 'marks unpaid order as processed without fulfillment operation' do
    order = create(:external_order, status: 'new', payment_status: 'pending')
    event = create(:external_order_event, external_order: order, processing_status: 'received')

    allow(Insales::ApiV1::FeatureFlags).to receive(:order_fulfillment_enabled?).and_return(false)

    processor.process(event_id: event.id)

    expect(event.reload.processing_status).to eq('processed')
    expect(order.reload.status).to eq('new')
    expect(order.external_fulfillment_operations.count).to eq(0)
  end

  it 'creates queued write-off operation for paid order when fulfillment is disabled' do
    order = create(:external_order, status: 'new', payment_status: 'paid')
    create(:external_order_item, external_order: order, sku: 'SKU-100', quantity: 1)
    event = create(:external_order_event, external_order: order, processing_status: 'received')

    allow(Insales::ApiV1::FeatureFlags).to receive(:order_fulfillment_enabled?).and_return(false)

    processor.process(event_id: event.id)

    operation = order.external_fulfillment_operations.first
    expect(operation).to be_present
    expect(operation.status).to eq('queued')
    expect(event.reload.processing_status).to eq('processed')
  end

  it 'processes paid order write-off when fulfillment is enabled' do
    product = create(:product, sku: 'SKU-PAID', ms_id: SecureRandom.uuid)
    stock = create(:product_stock, product: product, store_name: 'Тест', stock: 5, free_stock: 5)

    order = create(:external_order, payment_status: 'paid')
    create(:external_order_item, external_order: order, product: product, sku: 'SKU-PAID', quantity: 2)
    event = create(:external_order_event, external_order: order, processing_status: 'received')
    insales_setting = create(:insales_setting)
    insales_setting.update!(allowed_store_names: ['Тест'])

    response = instance_double(Faraday::Response, status: 201, body: { 'id' => 'MS-ORDER-1' })
    client = instance_double(MoyskladClient, create_demand: response)
    allow(MoyskladClient).to receive(:new).and_return(client)
    allow(Insales::ApiV1::FeatureFlags).to receive(:order_fulfillment_enabled?).and_return(true)

    processor.process(event_id: event.id)

    operation = order.external_fulfillment_operations.first
    expect(operation.status).to eq('succeeded')
    expect(operation.ms_document_id).to eq('MS-ORDER-1')
    expect(stock.reload.stock.to_d).to eq(3)
    expect(event.reload.processing_status).to eq('processed')
  end
end
