# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin InSales Orders', type: :request do
  let(:admin_user) { create(:admin_user) }

  before do
    sign_in admin_user, scope: :admin_user
  end

  it 'renders orders with statuses from InSales feed' do
    feed_result = Insales::OrdersFeed::Result.new(
      orders: [
        {
          id: 1001,
          number: 'ORD-1001',
          created_at: '2026-03-16T10:00:00Z',
          status: 'new',
          financial_status: 'paid',
          fulfillment_status: 'pending',
          total_price: '15000',
          currency: 'RUB',
          client_name: 'Иван',
          client_email: 'ivan@example.com',
          client_phone: '+79990001122',
          skus: ['SKU-17']
        }
      ],
      error: nil,
      page: 1,
      per_page: 50
    )

    feed = instance_double(Insales::OrdersFeed, call: feed_result)
    allow(Insales::OrdersFeed).to receive(:new).and_return(feed)

    get '/admin/insales_orders'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('ORD-1001')
    expect(response.body).to include('new')
    expect(response.body).to include('paid')
    expect(response.body).to include('pending')
    expect(response.body).to include('SKU-17')
  end
end
