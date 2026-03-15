# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin Dashboard', type: :request do
  let(:admin_user) { create(:admin_user) }

  before do
    sign_in admin_user, scope: :admin_user
  end

  it 'renders dashboard page' do
    get '/admin/dashboard'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Оперативная сводка')
  end

  it 'handles stop action via get' do
    get '/admin/dashboard/stop_syncs'

    expect(response).to have_http_status(:found)
    expect(response).to redirect_to('/admin/dashboard')
  end
end
