# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin InSales Category Mappings', type: :request do
  let(:admin_user) { create(:admin_user) }

  before do
    sign_in admin_user, scope: :admin_user
  end

  it 'renders mappings index' do
    get '/admin/insales_category_mappings'

    expect(response).to have_http_status(:ok)
  end

  it 'renders category status page' do
    get '/admin/insales_category_status'

    expect(response).to have_http_status(:ok)
  end
end
