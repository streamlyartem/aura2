# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Moysklad::HttpClient do
  it 'reports failing API responses to SentryReporter' do
    config = Moysklad::Config.new
    config.username = 'user'
    config.password = 'pass'
    client = described_class.new(config)

    stub_request(:get, 'https://api.moysklad.ru/api/remap/1.2/entity/product')
      .with(basic_auth: %w[user pass])
      .to_return(status: 500, body: '{"error":"boom"}', headers: { 'Content-Type' => 'application/json' })

    expect(Monitoring::SentryReporter).to receive(:report_moysklad_api_error).with(
      hash_including(
        message: 'Moysklad response 500',
        tags: hash_including(
          component: 'moysklad_http',
          http_status: 500,
          retryable: true
        ),
        extras: hash_including(url: 'https://api.moysklad.ru/api/remap/1.2/entity/product')
      )
    )

    expect do
      client.get('entity/product')
    end.to raise_error(Moysklad::HttpClient::RequestError, /Server error: 500/)
  end
end
