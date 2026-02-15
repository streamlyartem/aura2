# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::ExportMedia do
  let(:base_url) { 'https://example.myinsales.ru' }
  let(:login) { 'user' }
  let(:password) { 'pass' }

  before do
    InsalesSetting.create!(
      base_url: base_url,
      login: login,
      password: password,
      category_id: '777',
      default_collection_id: '999',
      image_url_mode: 'service_url'
    )
  end

  it 'uploads enabled images' do
    product = create(:product)
    image = create(:image, object: product)
    InsalesProductMapping.create!(
      aura_product_id: product.id,
      insales_product_id: 10,
      insales_variant_id: 55
    )
    InsalesMediaItem.create!(
      aura_product_id: product.id,
      kind: 'image',
      source_type: 'image',
      aura_image_id: image.id,
      position: 1
    )

    stub_request(:post, "#{base_url}/admin/products/10/images.json")
      .with(basic_auth: [login, password])
      .to_return(status: 201, body: { id: 777 }.to_json, headers: { 'Content-Type' => 'application/json' })

    result = described_class.new.call(product_id: product.id, dry_run: false)

    expect(result.images_uploaded).to eq(1)
    expect(result.images_errors).to eq(0)
  end

  it 'stores video links in description' do
    product = create(:product)
    InsalesProductMapping.create!(
      aura_product_id: product.id,
      insales_product_id: 11,
      insales_variant_id: 56
    )
    InsalesMediaItem.create!(
      aura_product_id: product.id,
      kind: 'video',
      source_type: 'url',
      url: 'https://video.example.com/1.mp4',
      position: 1
    )

    stub_request(:get, "#{base_url}/admin/products/11.json")
      .with(basic_auth: [login, password])
      .to_return(status: 200, body: { product: { id: 11, description: '' } }.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:put, "#{base_url}/admin/products/11.json")
      .with(basic_auth: [login, password])
      .to_return(status: 200, body: { product: { id: 11 } }.to_json, headers: { 'Content-Type' => 'application/json' })

    result = described_class.new.call(product_id: product.id, dry_run: false)

    expect(result.videos_selected).to eq(1)
    expect(result.videos_updated).to eq(1)
    expect(result.video_urls).to include('https://video.example.com/1.mp4')
  end
end
