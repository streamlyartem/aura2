# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin Products type filter', type: :request do
  let(:admin_user) { create(:admin_user, allowed_admin_paths: AdminUser::ADMIN_PAGE_OPTIONS.values) }

  before do
    sign_in admin_user, scope: :admin_user
  end

  it 'filters products by aura_product_type' do
    target_type = create(:aura_product_type, code: 'target', name: 'Target type', matcher_path_prefix: 'Срезы/Светлый')
    create(:aura_product_type, code: 'other', name: 'Other type', matcher_path_prefix: 'Срезы/Темный')

    target_product = create(:product, name: 'Target Product', path_name: 'Срезы/Светлый/55')
    create(:product, name: 'Other Product', path_name: 'Срезы/Темный/55')

    get '/admin/products', params: { q: { aura_product_type_id_eq: target_type.id } }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(target_product.name)
    expect(response.body).not_to include('Other Product')
  end
end
