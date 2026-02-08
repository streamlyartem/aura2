# frozen_string_literal: true

require 'rails_helper'
require 'services/concerns/moysklad_shared_contexts'

RSpec.describe 'API::Moysklad::Webhooks' do
  let(:token) { ENV.fetch('MOYSKLAD_WEBHOOK_TOKEN', 'testtoken') }
  let(:headers) { { 'CONTENT_TYPE' => 'application/json' } }
  let(:base_params) do
    {
      auditContext: {
        meta: { type: 'audit', href: 'https://api.moysklad.ru/api/remap/1.2/audit/123' },
        uid: 'admin@test',
        moment: Time.current.iso8601
      }
    }
  end

  before do
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
  end

  describe 'POST /api/moysklad/webhooks' do
    context 'when token is valid' do
      let(:product) { instance_spy(Product, id: 123) }

      before do
        allow(Product).to receive(:find_by).and_return(product)
      end

      include_context 'with moysklad get product mock' do
        let(:id_to_stub) { SecureRandom.uuid }
      end

      it 'handles product creation' do
        expect do
          post '/api/moysklad/webhooks',
               params: base_params.merge(
                 token: token,
                 events: [
                   {
                     meta: { type: 'product',
                             href: "https://api.moysklad.ru/api/remap/1.2/entity/product/#{id_to_stub}" },
                     action: 'CREATE'
                   }
                 ]
               ).to_json,
               headers: headers
        end.to change(Product, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(Rails.logger).to have_received(:info).with(/created/i)
      end

      it 'handles product update' do
        post '/api/moysklad/webhooks',
             params: base_params.merge(
               token: token,
               events: [
                 {
                   meta: { type: 'product',
                           href: "https://api.moysklad.ru/api/remap/1.2/entity/product/#{id_to_stub}" },
                   action: 'UPDATE'
                 }
               ]
             ).to_json,
             headers: headers

        expect(response).to have_http_status(:ok)
        expect(product).to have_received(:update!)
        expect(Rails.logger).to have_received(:info).with(/updated from Moysklad/)
      end

      it 'handles product deletion' do
        post '/api/moysklad/webhooks',
             params: base_params.merge(
               token: token,
               events: [
                 {
                   meta: { type: 'product', href: 'https://api.moysklad.ru/api/remap/1.2/entity/product/789' },
                   action: 'DELETE'
                 }
               ]
             ).to_json,
             headers: headers

        expect(product).to have_received(:destroy!)
        expect(Rails.logger).to have_received(:info).with(/deleted/i)
      end
    end

    context 'when token is invalid' do
      it 'returns unauthorized' do
        post '/api/moysklad/webhooks',
             params: base_params.merge(
               token: 'wrongtoken',
               events: [
                 {
                   meta: { type: 'product', href: 'https://api.moysklad.ru/api/remap/1.2/entity/product/123' },
                   action: 'CREATE'
                 }
               ]
             ).to_json,
             headers: headers

        expect(response).to have_http_status(:unauthorized)
        expect(Rails.logger).to have_received(:warn).with(/Unauthorized/)
      end
    end
  end
end
