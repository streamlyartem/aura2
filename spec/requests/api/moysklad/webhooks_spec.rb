# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Moysklad webhooks', type: :request do
  let(:token) { 'secret-token-1234' }

  before do
    ENV['MOYSKLAD_WEBHOOK_TOKEN'] = token
  end

  after do
    ENV.delete('MOYSKLAD_WEBHOOK_TOKEN')
  end

  it 'returns 401 without token' do
    post '/api/moysklad/webhooks', params: { events: [] }
    expect(response).to have_http_status(:unauthorized)
  end

  it 'returns 401 with wrong token' do
    post '/api/moysklad/webhooks', params: { token: 'wrong', events: [] }
    expect(response).to have_http_status(:unauthorized)
  end

  it 'accepts token in query params' do
    post '/api/moysklad/webhooks', params: { token: token, events: [] }
    expect(response).to have_http_status(:ok)
  end

  it 'accepts token in header' do
    post '/api/moysklad/webhooks', params: { events: [] }, headers: { 'X-Moysklad-Token' => token }
    expect(response).to have_http_status(:ok)
  end
end
