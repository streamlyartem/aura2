# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin InSales Catalog', type: :request do
  include ActiveJob::TestHelper

  let(:admin_user) { create(:admin_user) }

  before do
    sign_in admin_user, scope: :admin_user
  end

  it 'renders catalog page without all/skipped scope tabs' do
    get '/admin/insales_catalog_items'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('scope=error')
    expect(response.body).not_to include('scope=skipped')
    expect(response.body).not_to include('scope=all')
  end

  it 'enqueues prepare job from recalculate action' do
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs

    expect do
      post '/admin/insales_catalog_items/prepare_catalog'
    end.to have_enqueued_job(Insales::Catalog::PrepareJob)

    expect(response).to have_http_status(:found)
    expect(response).to redirect_to('/admin/insales_catalog_items')
  ensure
    clear_enqueued_jobs
  end
end
