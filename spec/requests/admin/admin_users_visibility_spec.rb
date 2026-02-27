# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin Users visibility', type: :request do
  let(:super_admin) { create(:admin_user, allowed_admin_paths: AdminUser::ADMIN_PAGE_OPTIONS.values) }

  before do
    sign_in super_admin, scope: :admin_user
  end

  it 'saves selected allowed pages from checkboxes' do
    managed_user = create(:admin_user)
    selected_paths = ['/admin/dashboard', '/admin/products']

    patch "/admin/admin_users/#{managed_user.id}", params: {
      admin_user: {
        email: managed_user.email,
        allowed_admin_paths: selected_paths
      }
    }

    expect(response).to have_http_status(:see_other)
    expect(managed_user.reload.allowed_admin_paths).to match_array(selected_paths)
    expect(managed_user.restrict_admin_pages).to eq(true)
  end

  it 'blocks access to non-selected section' do
    sign_out super_admin
    restricted_admin = create(:admin_user, allowed_admin_paths: ['/admin/dashboard'])
    sign_in restricted_admin, scope: :admin_user

    get '/admin/products'

    expect(response).to redirect_to('/admin/dashboard')
    follow_redirect!
    expect(response.body).to include('У вас нет доступа к этому разделу.')
  end
end
