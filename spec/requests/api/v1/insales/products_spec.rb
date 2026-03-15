# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API v1 InSales Products', type: :request do
  let!(:product) { create(:product, sku: 'SKU-42', retail_price: 123.45, weight: 50, length: 60) }

  before do
    allow(Insales::ApiV1::FeatureFlags).to receive(:auth_token).and_return('')
    allow(Insales::ApiV1::FeatureFlags).to receive(:read_enabled?).and_return(true)
    allow(Insales::ApiV1::FeatureFlags).to receive(:write_enabled?).and_return(true)
    allow(Insales::ApiV1::FeatureFlags).to receive(:outbox_enabled?).and_return(true)
  end

  describe 'GET /api/v1/insales/products/:external_id' do
    it 'returns product snapshot by id' do
      get "/api/v1/insales/products/#{product.id}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['external_id']).to eq(product.id)
      expect(json['sku']).to eq('SKU-42')
      expect(json['price_minor']).to eq(12_345)
    end

    it 'returns product snapshot by sku' do
      get '/api/v1/insales/products/SKU-42', params: { by: 'sku' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['external_id']).to eq(product.id)
    end
  end

  describe 'GET /api/v1/insales/products/changes' do
    it 'returns cursor feed' do
      create(:sync_outbox_event, aggregate_id: product.id, payload: { external_id: product.id, sku: product.sku })

      get '/api/v1/insales/products/changes', params: { limit: 10 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['items']).not_to be_empty
      expect(json['next_cursor']).to be_present
      expect(json['has_more']).to eq(false)
    end
  end

  describe 'DELETE /api/v1/insales/products/:external_id' do
    it 'writes delete event and returns status' do
      expect do
        delete "/api/v1/insales/products/#{product.id}"
      end.to change(SyncOutboxEvent, :count).by(1)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('deleted')
      expect(SyncOutboxEvent.last.event_type).to eq('product.deleted')
    end
  end
end
