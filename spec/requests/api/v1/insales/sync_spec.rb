# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API v1 InSales Sync', type: :request do
  include ActiveJob::TestHelper

  before do
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    perform_enqueued_jobs do
      # noop to ensure adapter initialized
    end

    allow(Insales::ApiV1::FeatureFlags).to receive(:auth_token).and_return('')
    allow(Insales::ApiV1::FeatureFlags).to receive(:read_enabled?).and_return(true)
    allow(Insales::ApiV1::FeatureFlags).to receive(:write_enabled?).and_return(true)
    allow(Insales::ApiV1::FeatureFlags).to receive(:outbox_enabled?).and_return(false)
    allow(Insales::ApiV1::FeatureFlags).to receive(:full_sync_enabled?).and_return(true)
  end

  after do
    clear_enqueued_jobs
  end

  describe 'POST /api/v1/insales/sync/upsert' do
    let(:payload) do
      {
        source: 'aura',
        batch_id: SecureRandom.uuid,
        items: [
          {
            external_id: SecureRandom.uuid,
            sku: 'SKU-UPSERT-1',
            name: 'API product',
            updated_at: Time.current.iso8601,
            currency: 'RUB',
            price_minor: 10_000,
            stock_qty: 4
          }
        ]
      }
    end

    it 'creates async run and supports idempotent replay' do
      expect do
        post '/api/v1/insales/sync/upsert', params: payload.to_json,
                                             headers: { 'CONTENT_TYPE' => 'application/json', 'Idempotency-Key' => 'idem-1' }
      end.to change(InsalesApiSyncRun, :count).by(1)

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      run = InsalesApiSyncRun.find(body['run_id'])
      expect(run.status).to eq('queued')

      post '/api/v1/insales/sync/upsert', params: payload.to_json,
                                           headers: { 'CONTENT_TYPE' => 'application/json', 'Idempotency-Key' => 'idem-1' }
      expect(response).to have_http_status(:accepted)
      expect(InsalesApiSyncRun.count).to eq(1)
    end

    it 'returns conflict for same key with different payload' do
      post '/api/v1/insales/sync/upsert', params: payload.to_json,
                                           headers: { 'CONTENT_TYPE' => 'application/json', 'Idempotency-Key' => 'idem-2' }
      expect(response).to have_http_status(:accepted)

      payload[:items].first[:sku] = 'SKU-DIFFERENT'
      post '/api/v1/insales/sync/upsert', params: payload.to_json,
                                           headers: { 'CONTENT_TYPE' => 'application/json', 'Idempotency-Key' => 'idem-2' }

      expect(response).to have_http_status(:conflict)
      body = JSON.parse(response.body)
      expect(body.dig('error', 'code')).to eq('IDEMPOTENCY_CONFLICT')
    end
  end

  describe 'GET /api/v1/insales/sync/runs/:id' do
    it 'returns run status payload' do
      run = create(:insales_api_sync_run, status: 'running', processed: 2, created_count: 1)

      get "/api/v1/insales/sync/runs/#{run.id}"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['run_id']).to eq(run.id)
      expect(body.dig('stats', 'processed')).to eq(2)
      expect(body.dig('stats', 'created')).to eq(1)
    end
  end
end
