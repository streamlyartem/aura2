# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin MoySklad Settings', type: :request do
  let(:admin_user) { create(:admin_user) }
  let!(:insales_setting) { create(:insales_setting, allowed_store_names: ['Тест']) }

  before do
    sign_in admin_user, scope: :admin_user
  end

  it 'renders settings page' do
    get '/admin/moysklad_settings'
    expect(response).to have_http_status(:ok)
  end

  it 'enqueues ensure webhooks' do
    post '/admin/moysklad_settings/ensure_webhooks'
    expect(response).to have_http_status(:found)
  end

  it 'enqueues import products' do
    allow_any_instance_of(MoyskladClient).to receive(:store_names).and_return(['Тест'])
    allow(Moysklad::ImportProductsJob).to receive(:enqueue_once).and_return(true)

    post '/admin/moysklad_settings/import_products'

    expect(Moysklad::ImportProductsJob).to have_received(:enqueue_once).with(
      store_names: ['Тест'],
      full_import: true
    )
    expect(response).to have_http_status(:found)
  end

  it 'shows error when no stores selected' do
    insales_setting.update!(allowed_store_names: [])
    allow(Moysklad::ImportProductsJob).to receive(:enqueue_once)

    post '/admin/moysklad_settings/import_products'

    expect(Moysklad::ImportProductsJob).not_to have_received(:enqueue_once)
    expect(flash[:alert]).to eq('Выберите хотя бы один склад в "Настройки InSales".')
    expect(response).to have_http_status(:found)
  end
end
