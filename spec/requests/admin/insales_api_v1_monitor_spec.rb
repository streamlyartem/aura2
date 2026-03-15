# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin InSales API v1 Monitor', type: :request do
  let(:admin_user) { create(:admin_user) }

  before do
    sign_in admin_user, scope: :admin_user
  end

  it 'renders monitor page' do
    get '/admin/insales_api_v1_monitor'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Мониторинг миграции API v1')
    expect(response.body).to include('Outbox событий всего')
  end

  it 'handles stop action' do
    post '/admin/insales_api_v1_monitor/stop_syncs'

    expect(response).to have_http_status(:found)
    expect(response).to redirect_to('/admin/insales_api_v1_monitor')
  end
end
