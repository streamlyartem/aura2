# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin InSales Settings', type: :request do
  let(:admin_user) { create(:admin_user) }

  before do
    sign_in admin_user
  end

  it 'renders settings page' do
    get '/admin/insales_settings'
    expect(response).to have_http_status(:ok)
  end

  it 'enqueues sync job' do
    post '/admin/insales_settings/sync_now', params: { store_name: 'Тест' }
    expect(response).to have_http_status(:found)
  end
end
