# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Aura products admin pages', type: :request do
  let(:admin_user) { create(:admin_user, allowed_admin_paths: AdminUser::ADMIN_PAGE_OPTIONS.values) }

  before do
    sign_in admin_user, scope: :admin_user
  end

  it 'opens products status page' do
    get '/admin/aura_products_status'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Статус по товарам')
  end

  it 'opens product types page' do
    get '/admin/aura_product_types'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Типы товаров')
  end

  it 'opens sources page' do
    get '/admin/aura_product_sources'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Источники')
  end
end
