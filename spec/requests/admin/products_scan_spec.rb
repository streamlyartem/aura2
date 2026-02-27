# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin Products scan', type: :request do
  let(:admin_user) { create(:admin_user) }

  before do
    sign_in admin_user, scope: :admin_user
  end

  it 'finds product by normalized barcode from barcodes payload' do
    product = create(:product, sku: '1805327132', code: '1805327132', barcodes: [{ 'code128' => '001805327132' }])

    get '/admin/products/check_sku', params: { sku: '0001805327132' }, as: :json

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body['exists']).to eq(true)
    expect(body['id']).to eq(product.id)
  end

  it 'returns not found when barcode does not match' do
    create(:product, sku: 'ABC-1', code: 'ABC-1', barcodes: [{ 'code128' => '001234' }])

    get '/admin/products/check_sku', params: { sku: '999999' }, as: :json

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body['exists']).to eq(false)
  end
end
