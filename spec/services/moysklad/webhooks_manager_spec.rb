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

  describe 'desired payloads' do
    it 'includes product and demand webhooks for create/update/delete' do
      manager = described_class.new
      allow(manager).to receive(:webhook_url).and_return('https://example.com/api/moysklad/webhooks?token=x')

      payloads = manager.send(:desired_payloads)

      expect(payloads.size).to eq(6)
      expect(payloads).to include(
        { 'url' => 'https://example.com/api/moysklad/webhooks?token=x', 'action' => 'CREATE', 'entityType' => 'product' },
        { 'url' => 'https://example.com/api/moysklad/webhooks?token=x', 'action' => 'UPDATE', 'entityType' => 'product' },
        { 'url' => 'https://example.com/api/moysklad/webhooks?token=x', 'action' => 'DELETE', 'entityType' => 'product' },
        { 'url' => 'https://example.com/api/moysklad/webhooks?token=x', 'action' => 'CREATE', 'entityType' => 'demand' },
        { 'url' => 'https://example.com/api/moysklad/webhooks?token=x', 'action' => 'UPDATE', 'entityType' => 'demand' },
        { 'url' => 'https://example.com/api/moysklad/webhooks?token=x', 'action' => 'DELETE', 'entityType' => 'demand' }
      )
    end
  end
end
