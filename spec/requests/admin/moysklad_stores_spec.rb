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

  it 'applies checkbox selection after submit' do
    first = create(:moysklad_store, name: 'Тест', selected_for_import: true)
    second = create(:moysklad_store, name: 'Москва Бауманская', selected_for_import: false)

    post '/admin/moysklad_stores/apply_selection', params: { selected_store_ids: [second.id] }

    expect(response).to have_http_status(:found)
    expect(first.reload.selected_for_import).to eq(false)
    expect(second.reload.selected_for_import).to eq(true)
  end
end
