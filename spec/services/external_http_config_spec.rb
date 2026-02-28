# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExternalHttpConfig do
  around do |example|
    original = ENV.to_hash
    example.run
  ensure
    ENV.replace(original)
  end

  it 'applies service-specific values to Faraday options' do
    ENV['INSALES_HTTP_OPEN_TIMEOUT'] = '7'
    ENV['INSALES_HTTP_READ_TIMEOUT'] = '22'
    ENV['INSALES_HTTP_WRITE_TIMEOUT'] = '9'

    options = Faraday::RequestOptions.new
    described_class.apply_faraday!(options, service: :insales, open_timeout: 5, read_timeout: 15)

    expect(options.open_timeout).to eq(7.0)
    expect(options.timeout).to eq(22.0)
    expect(options.write_timeout).to eq(9.0)
  end

  it 'falls back to defaults when env values are invalid' do
    ENV['MOYSKLAD_HTTP_OPEN_TIMEOUT'] = 'oops'

    http = Net::HTTP.new('example.com', 443)
    described_class.apply_net_http!(http, service: :moysklad, open_timeout: 5, read_timeout: 120)

    expect(http.open_timeout).to eq(5)
    expect(http.read_timeout).to eq(120)
  end

  it 'uses global retry fallback when service-specific max retries is missing' do
    ENV['HTTP_MAX_RETRIES'] = '6'

    expect(described_class.max_retries(:insales, default: 5)).to eq(6)
  end
end
