# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin ProductStocks write_off', type: :request do
  let(:admin_user) { create(:admin_user) }

  before do
    sign_in admin_user, scope: :admin_user
  end

  it 'does not return 500 when MoySklad rejects write-off' do
    product = create(:product, ms_id: SecureRandom.uuid)
    stock = create(:product_stock, product: product, stock: 10, free_stock: 10, reserve: 0, store_name: 'Тест')

    client = instance_double(MoyskladClient)
    allow(MoyskladClient).to receive(:new).and_return(client)
    allow(client).to receive(:create_demand).and_raise(Moysklad::HttpClient::RequestError.new('Client error: 412'))

    post "/admin/product_stocks/#{stock.id}/write_off",
         params: { product_stock: { stock: '5' } }

    expect(response).to have_http_status(:found)
    expect(response).to redirect_to("/admin/product_stocks/#{stock.id}")
  end

  it 'does not call MoySklad when available stock is zero' do
    product = create(:product, ms_id: SecureRandom.uuid)
    stock = create(:product_stock, product: product, stock: 0, free_stock: 0, reserve: 0, store_name: 'Тест')

    expect(MoyskladClient).not_to receive(:new)

    post "/admin/product_stocks/#{stock.id}/write_off",
         params: { product_stock: { stock: '1' } }

    expect(response).to have_http_status(:found)
    expect(response).to redirect_to("/admin/product_stocks/#{stock.id}")
  end

  it 'uses stock-reserve fallback when free_stock is zero' do
    product = create(:product, ms_id: SecureRandom.uuid)
    stock = create(:product_stock, product: product, stock: 10, free_stock: 0, reserve: 0, store_name: 'Тест')

    client = instance_double(MoyskladClient)
    ms_response = instance_double(Faraday::Response, status: 201)
    allow(MoyskladClient).to receive(:new).and_return(client)
    allow(client).to receive(:create_demand).and_return(ms_response)

    post "/admin/product_stocks/#{stock.id}/write_off",
         params: { product_stock: { stock: '1' } }

    expect(response).to have_http_status(:found)
    expect(response).to redirect_to("/admin/product_stocks/#{stock.id}")
    expect(client).to have_received(:create_demand)
  end
end
