# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API v1 InSales inbound orders', type: :request do
  include ActiveJob::TestHelper

  let(:payload) do
    {
      source_event_id: 'evt-1001',
      event_type: 'order.updated',
      event_at: Time.current.iso8601,
      order: {
        id: 'insales-order-1',
        number: 'INS-1001',
        status: 'new',
        payment_status: 'pending',
        total_price: '1500.50',
        currency: 'RUB',
        order_lines: [
          { sku: 'SKU-1', quantity: 1, sale_price: '1500.50' }
        ]
      }
    }
  end

  before do
    clear_enqueued_jobs
    allow(Insales::ApiV1::FeatureFlags).to receive(:inbound_orders_enabled?).and_return(true)
    allow(Insales::ApiV1::FeatureFlags).to receive(:inbound_orders_processing_enabled?).and_return(false)
    allow(Insales::ApiV1::FeatureFlags).to receive(:inbound_orders_secret).and_return('')
    allow(Insales::ApiV1::FeatureFlags).to receive(:auth_token).and_return('test-token')
  end

  it 'ingests order event and returns accepted' do
    expect do
      post '/api/v1/insales/inbound/orders/events',
           params: payload.to_json,
           headers: { 'CONTENT_TYPE' => 'application/json', 'Authorization' => 'Bearer test-token' }
    end.to change(ExternalOrderEvent, :count).by(1)
      .and change(ExternalOrder, :count).by(1)
      .and change(ExternalOrderItem, :count).by(1)

    expect(response).to have_http_status(:accepted)
    body = JSON.parse(response.body)
    expect(body['status']).to eq('accepted')
    expect(body['replay']).to eq(false)
  end

  it 'returns replay for duplicate event id' do
    post '/api/v1/insales/inbound/orders/events',
         params: payload.to_json,
         headers: { 'CONTENT_TYPE' => 'application/json', 'Authorization' => 'Bearer test-token' }
    expect(response).to have_http_status(:accepted)

    post '/api/v1/insales/inbound/orders/events',
         params: payload.to_json,
         headers: { 'CONTENT_TYPE' => 'application/json', 'Authorization' => 'Bearer test-token' }

    expect(response).to have_http_status(:accepted)
    body = JSON.parse(response.body)
    expect(body['status']).to eq('replayed')
    expect(ExternalOrderEvent.count).to eq(1)
  end
end
