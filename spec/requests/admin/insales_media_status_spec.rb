# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin InSales Media Status', type: :request do
  let(:admin_user) { create(:admin_user) }

  before do
    sign_in admin_user
  end

  it 'renders media status index' do
    create(:product)
    get '/admin/insales_media_status'
    expect(response).to have_http_status(:ok)
  end

  it 'renders media status details' do
    product = create(:product)
    InsalesMediaStatus.create!(product_id: product.id, status: 'in_progress')
    get '/admin/insales_media_status', params: { product_id: product.id }
    expect(response).to have_http_status(:ok)
  end

  it 'enqueues recheck job' do
    product = create(:product)
    post '/admin/insales_media_status/recheck', params: { product_id: product.id }
    expect(response).to have_http_status(:found)
  end
end
