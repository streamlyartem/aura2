# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::VerifyMediaVisibility do
  let(:base_url) { 'https://shop.example.com' }
  let(:insales_product_id) { 123 }
  let(:image_url) { 'https://cdn.insales.example.com/images/1.png' }
  let(:file_path) { Rails.root.join('spec/support/images/files/borsch.png') }
  let(:file_bytes) { File.binread(file_path) }
  let(:image_checksum) { Digest::MD5.base64digest(file_bytes) }

  let(:product) { create(:product, name: 'Test Product', sku: 'SKU1') }
  let(:image) { create(:image, object: product) }
  let(:video) { create(:image, object: product, file: FactoryHelpers.upload_file('spec/support/images/files/borsch.png', 'video/mp4')) }

  before do
    InsalesSetting.create!(base_url: base_url, login: 'login', password: 'password', category_id: '1', image_url_mode: 'service_url')
    InsalesProductMapping.create!(aura_product_id: product.id, insales_product_id: insales_product_id)
    Rails.application.routes.default_url_options[:host] = 'example.test'
  end

  it 'marks status success when API and storefront checks pass' do
    video_url = video.url

    stub_request(:get, "#{base_url}/admin/products/#{insales_product_id}.json")
      .to_return(status: 200, body: { product: { id: insales_product_id, description: "Video: #{video_url}", permalink: 'test-product' } }.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:get, "#{base_url}/admin/products/#{insales_product_id}/images.json")
      .to_return(status: 200, body: { images: [{ id: 1, url: image_url }] }.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:get, image_url).to_return(status: 200, body: file_bytes)

    storefront_url = "#{base_url}/product/test-product"
    storefront_html = "<html><img src=\"#{image_url}\"><a href=\"#{video_url}\">video</a></html>"
    stub_request(:get, storefront_url).to_return(status: 200, body: storefront_html)

    stub_request(:get, video_url).to_return(status: 200, body: 'ok')

    result = described_class.new.call(product: product)

    expect(result.status).to eq('success')
    status = InsalesMediaStatus.find_by(product_id: product.id)
    expect(status.status).to eq('success')

    items = InsalesMediaStatusItem.where(product_id: product.id)
    expect(items.count).to eq(2)
    expect(items.all? { |item| item.status == 'success' }).to be(true)
    expect(InsalesMediaStatusItem.find_by(source_key: "aura_image:#{image.id}").source_checksum).to eq(image_checksum)
  end

  it 'marks error when storefront html does not contain image url' do
    video_url = video.url

    stub_request(:get, "#{base_url}/admin/products/#{insales_product_id}.json")
      .to_return(status: 200, body: { product: { id: insales_product_id, description: "Video: #{video_url}", permalink: 'test-product' } }.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:get, "#{base_url}/admin/products/#{insales_product_id}/images.json")
      .to_return(status: 200, body: { images: [{ id: 1, url: image_url }] }.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:get, image_url).to_return(status: 200, body: file_bytes)

    storefront_url = "#{base_url}/product/test-product"
    storefront_html = "<html><div>No images here</div></html>"
    stub_request(:get, storefront_url).to_return(status: 200, body: storefront_html)

    result = described_class.new.call(product: product)

    expect(result.status).to eq('error')
    status = InsalesMediaStatus.find_by(product_id: product.id)
    expect(status.status).to eq('error')

    image_item = InsalesMediaStatusItem.find_by(source_key: "aura_image:#{image.id}")
    expect(image_item.storefront_ok).to be(false)
    expect(image_item.storefront_error).to be_present
  end

  it 'marks in_progress when API has no matching image' do
    stub_request(:get, "#{base_url}/admin/products/#{insales_product_id}.json")
      .to_return(status: 200, body: { product: { id: insales_product_id, description: '', permalink: 'test-product' } }.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:get, "#{base_url}/admin/products/#{insales_product_id}/images.json")
      .to_return(status: 200, body: { images: [] }.to_json, headers: { 'Content-Type' => 'application/json' })

    storefront_url = "#{base_url}/product/test-product"
    stub_request(:get, storefront_url).to_return(status: 200, body: '<html></html>')

    result = described_class.new.call(product: product)

    expect(result.status).to eq('in_progress')
    status = InsalesMediaStatus.find_by(product_id: product.id)
    expect(status.status).to eq('in_progress')
  end
end
