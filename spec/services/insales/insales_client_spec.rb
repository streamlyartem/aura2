# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::InsalesClient do
  it 'reports non-success API responses to SentryReporter' do
    client = described_class.new(
      base_url: 'https://example.myinsales.ru',
      login: 'user',
      password: 'pass'
    )

    stub_request(:get, 'https://example.myinsales.ru/admin/products/404.json')
      .with(basic_auth: %w[user pass])
      .to_return(status: 404, body: { message: 'missing' }.to_json, headers: { 'Content-Type' => 'application/json' })

    expect(Monitoring::SentryReporter).to receive(:report_insales_api_error).with(
      hash_including(
        message: 'InSales GET /admin/products/404.json returned 404',
        tags: hash_including(
          component: 'insales_client',
          http_method: 'GET',
          http_status: 404,
          retryable: false
        ),
        extras: hash_including(path: '/admin/products/404.json')
      )
    )

    response = client.get('/admin/products/404.json')

    expect(response.status).to eq(404)
  end
end
