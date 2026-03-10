# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin InSales Media Status', type: :request do
  let(:admin_user) { create(:admin_user) }

  before do
    sign_in admin_user, scope: :admin_user
  end

  it 'renders media status index' do
    create(:product)
    get '/admin/insales_media_status'
    expect(response).to have_http_status(:ok)
  end

  it 'renders media status show' do
    product = create(:product)
    InsalesMediaSyncState.create!(product_id: product.id, status: 'in_progress')
    get '/admin/insales_media_status', params: { product_id: product.id }
    expect(response).to have_http_status(:ok)
  end

  it 'shows actual video count for product media' do
    product = create(:product)
    create(:image, object: product)
    create(
      :image,
      object: product,
      file: FactoryHelpers.upload_file(
        'spec/support/images/files/wrong_format.php',
        'video/quicktime',
        binary: false
      )
    )

    get '/admin/insales_media_status', params: { product_id: product.id }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Videos in AURA')
    expect(response.body).to match(/<td data-column="value">1<\/td>/)
  end
end
