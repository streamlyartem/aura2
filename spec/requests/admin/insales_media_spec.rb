# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin InSales Media', type: :request do
  let(:admin_user) { create(:admin_user) }

  before do
    allow_any_instance_of(Warden::Proxy).to receive(:authenticate).and_return(admin_user)
    allow_any_instance_of(Warden::Proxy).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(Warden::Proxy).to receive(:user).and_return(admin_user)

    InsalesSetting.create!(
      base_url: 'https://example.myinsales.ru',
      login: 'login',
      password: 'password',
      category_id: '1',
      image_url_mode: 'service_url',
      allowed_store_names: ['Тест']
    )
  end

  it 'renders page and updates media toggles' do
    get '/admin/insales_media'
    expect(response).to have_http_status(:ok)

    post '/admin/insales_media/update', params: { sync_images_enabled: '0', sync_videos_enabled: '1' }

    expect(response).to have_http_status(:found)
    setting = InsalesSetting.first
    expect(setting.sync_images_enabled?).to eq(false)
    expect(setting.sync_videos_enabled?).to eq(true)
  end
end
