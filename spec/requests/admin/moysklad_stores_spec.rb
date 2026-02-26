# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin MoySklad Stores', type: :request do
  let(:admin_user) { create(:admin_user) }

  before do
    sign_in admin_user, scope: :admin_user
  end

  it 'renders stores page' do
    get '/admin/moysklad_stores'

    expect(response).to have_http_status(:ok)
  end

  it 'refreshes stores list' do
    allow_any_instance_of(MoyskladClient).to receive(:store_names).and_return(['Тест', 'Москва Бауманская'])

    post '/admin/moysklad_stores/refresh'

    expect(response).to have_http_status(:found)
    expect(MoyskladStore.order(:name).pluck(:name)).to eq(['Москва Бауманская', 'Тест'])
  end
end
