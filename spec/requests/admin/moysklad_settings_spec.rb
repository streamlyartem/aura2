# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin MoySklad Settings', type: :request do
  let(:admin_user) { create(:admin_user) }

  before do
    sign_in admin_user
  end

  it 'renders settings page' do
    get '/admin/moysklad_settings'
    expect(response).to have_http_status(:ok)
  end

  it 'enqueues ensure webhooks' do
    post '/admin/moysklad_settings/ensure_webhooks'
    expect(response).to have_http_status(:found)
  end

  it 'enqueues import products' do
    post '/admin/moysklad_settings/import_products'
    expect(response).to have_http_status(:found)
  end
end
