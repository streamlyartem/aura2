# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin Orders pages', type: :request do
  let(:admin_user) { create(:admin_user) }

  before do
    sign_in admin_user, scope: :admin_user
  end

  it 'renders orders root page' do
    create(:external_order, source: 'insales', external_order_number: 'INS-1001')
    get '/admin/orders'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('INS-1001')
  end

  it 'renders order statuses page' do
    create(:external_order, status: 'paid', payment_status: 'paid')
    get '/admin/order_statuses'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Сводка')
  end

  it 'renders order write offs page' do
    order = create(:external_order)
    create(:external_fulfillment_operation, external_order: order, status: 'succeeded', ms_document_id: 'MS-123')
    get '/admin/order_write_offs'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('MS-123')
  end
end
