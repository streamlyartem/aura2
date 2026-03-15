# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::OrdersFeed do
  let(:client) { instance_double(Insales::InsalesClient) }
  let(:service) { described_class.new(client: client) }

  it 'normalizes orders and includes statuses and skus' do
    response = instance_double(
      Faraday::Response,
      status: 200,
      body: {
        'orders' => [
          {
            'id' => 11,
            'number' => 'A-11',
            'status' => 'new',
            'financial_status' => 'paid',
            'fulfillment_status' => 'pending',
            'client' => { 'name' => 'Иван', 'email' => 'ivan@example.com' },
            'order_lines' => [
              { 'sku' => 'SKU-1' },
              { 'variant' => { 'sku' => 'SKU-2' } }
            ]
          }
        ]
      }
    )

    allow(client).to receive(:get).with('/admin/orders.json', hash_including(page: 1, per_page: 50)).and_return(response)

    result = service.call

    expect(result.error).to be_nil
    expect(result.orders.size).to eq(1)
    expect(result.orders.first[:status]).to eq('new')
    expect(result.orders.first[:financial_status]).to eq('paid')
    expect(result.orders.first[:fulfillment_status]).to eq('pending')
    expect(result.orders.first[:skus]).to contain_exactly('SKU-1', 'SKU-2')
  end

  it 'filters by sku' do
    response = instance_double(
      Faraday::Response,
      status: 200,
      body: {
        'orders' => [
          { 'id' => 1, 'order_lines' => [{ 'sku' => 'ABC-001' }] },
          { 'id' => 2, 'order_lines' => [{ 'sku' => 'XYZ-002' }] }
        ]
      }
    )
    allow(client).to receive(:get).and_return(response)

    result = service.call(sku: 'xyz')

    expect(result.orders.map { |row| row[:id] }).to eq([2])
  end
end
