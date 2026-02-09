# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Moysklad::WebhooksManager do
  describe 'webhook url building' do
    it 'appends token to url without query' do
      manager = described_class.new
      url = manager.send(:append_token, 'https://example.com/api/moysklad/webhooks', 'abc123')
      expect(url).to eq('https://example.com/api/moysklad/webhooks?token=abc123')
    end

    it 'preserves existing query params and adds token' do
      manager = described_class.new
      url = manager.send(:append_token, 'https://example.com/api/moysklad/webhooks?requestId=1', 'abc123')
      expect(url).to eq('https://example.com/api/moysklad/webhooks?requestId=1&token=abc123')
    end
  end
end
