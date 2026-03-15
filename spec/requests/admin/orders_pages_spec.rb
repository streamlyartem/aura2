# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin Orders pages', type: :request do
  let(:admin_user) { create(:admin_user) }

  before do
    sign_in admin_user, scope: :admin_user
  end

  it 'renders orders root page' do
    get '/admin/orders'
    expect(response).to have_http_status(:ok)
  end

  it 'renders order statuses page' do
    get '/admin/order_statuses'
    expect(response).to have_http_status(:ok)
  end

  it 'renders order write offs page' do
    get '/admin/order_write_offs'
    expect(response).to have_http_status(:ok)
  end
end
