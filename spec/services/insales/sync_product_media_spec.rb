# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::SyncProductMedia do
  let(:base_url) { 'https://shop.example.com' }
  let(:insales_product_id) { 123 }
  let(:image_url_1) { 'https://cdn.insales.example.com/images/1.png' }
  let(:image_url_2) { 'https://cdn.insales.example.com/images/2.png' }

  let(:product) { create(:product, name: 'Test Product', sku: 'SKU1', path_name: 'test-product') }

  before do
    stub_const('Insales::SyncProductMedia::ADMIN_VERIFY_ATTEMPTS', 1)
    stub_const('Insales::SyncProductMedia::STOREFRONT_VERIFY_ATTEMPTS', 1)
    stub_const('Insales::SyncProductMedia::VERIFY_RETRY_DELAY', 0)

    InsalesSetting.create!(
      base_url: base_url,
      login: 'login',
      password: 'password',
      category_id: '1',
      image_url_mode: 'service_url',
      allowed_store_names: ['Тест']
    )
    InsalesProductMapping.create!(aura_product_id: product.id, insales_product_id: insales_product_id)
    Rails.application.routes.default_url_options[:host] = 'example.test'

    create(:image, object: product)
    create(:image, object: product)
  end

  it 'marks success when admin and storefront verification pass' do
    stub_request(:post, "#{base_url}/admin/products/#{insales_product_id}/images.json")
      .to_return(status: 200, body: { image: { id: 1 } }.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:get, "#{base_url}/admin/products/#{insales_product_id}/images.json")
      .to_return(
        { status: 200, body: { images: [] }.to_json, headers: { 'Content-Type' => 'application/json' } },
        { status: 200, body: { images: [{ url: image_url_1 }, { url: image_url_2 }] }.to_json, headers: { 'Content-Type' => 'application/json' } }
      )

    stub_request(:get, "#{base_url}/admin/products/#{insales_product_id}.json")
      .to_return(status: 200, body: { product: { id: insales_product_id, permalink: 'test-product' } }.to_json, headers: { 'Content-Type' => 'application/json' })

    storefront_url = "#{base_url}/product/test-product"
    storefront_html = "<img src=\"#{image_url_1}\"><img src=\"#{image_url_2}\">"
    stub_request(:get, storefront_url).to_return(status: 200, body: storefront_html)
    stub_request(:get, image_url_1).to_return(status: 200, body: 'image1')
    stub_request(:get, image_url_2).to_return(status: 200, body: 'image2')

    result = described_class.new.call(product: product, insales_product_id: insales_product_id)

    expect(result.status).to eq('success')
    state = InsalesMediaSyncState.find_by(product_id: product.id)
    expect(state.status).to eq('success')
    expect(state.verified_admin).to be(true)
    expect(state.verified_storefront).to be(true)
  end

  it 'marks in_progress when admin verification is not ready yet' do
    stub_request(:post, "#{base_url}/admin/products/#{insales_product_id}/images.json")
      .to_return(status: 200, body: { image: { id: 1 } }.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:get, "#{base_url}/admin/products/#{insales_product_id}/images.json")
      .to_return(
        { status: 200, body: { images: [] }.to_json, headers: { 'Content-Type' => 'application/json' } },
        { status: 200, body: { images: [] }.to_json, headers: { 'Content-Type' => 'application/json' } }
      )

    result = described_class.new.call(product: product, insales_product_id: insales_product_id)

    state = InsalesMediaSyncState.find_by(product_id: product.id)
    expect(result.status).to eq('in_progress')
    expect(state.status).to eq('in_progress')
    expect(state.verified_admin).to be(false)
  end

  it 'marks in_progress when storefront verification is not ready yet' do
    stub_request(:post, "#{base_url}/admin/products/#{insales_product_id}/images.json")
      .to_return(status: 200, body: { image: { id: 1 } }.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:get, "#{base_url}/admin/products/#{insales_product_id}/images.json")
      .to_return(
        { status: 200, body: { images: [] }.to_json, headers: { 'Content-Type' => 'application/json' } },
        { status: 200, body: { images: [{ url: image_url_1 }, { url: image_url_2 }] }.to_json, headers: { 'Content-Type' => 'application/json' } }
      )

    stub_request(:get, "#{base_url}/admin/products/#{insales_product_id}.json")
      .to_return(status: 200, body: { product: { id: insales_product_id, permalink: 'test-product' } }.to_json, headers: { 'Content-Type' => 'application/json' })

    storefront_url = "#{base_url}/product/test-product"
    storefront_html = "<img src=\"#{image_url_1}\">"
    stub_request(:get, storefront_url).to_return(status: 200, body: storefront_html)
    stub_request(:get, image_url_1).to_return(status: 200, body: 'image1')

    result = described_class.new.call(product: product, insales_product_id: insales_product_id)

    expect(result.status).to eq('in_progress')
    state = InsalesMediaSyncState.find_by(product_id: product.id)
    expect(state.verified_storefront).to be(false)
  end

  it 'removes stale remote images before upload to prevent duplicates' do
    stale_image_id = 999

    stub_request(:delete, "#{base_url}/admin/products/#{insales_product_id}/images/#{stale_image_id}.json")
      .to_return(status: 200, body: {}.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:post, "#{base_url}/admin/products/#{insales_product_id}/images.json")
      .to_return(status: 200, body: { image: { id: 1 } }.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:get, "#{base_url}/admin/products/#{insales_product_id}/images.json")
      .to_return(
        { status: 200, body: { images: [{ id: stale_image_id, url: image_url_1 }] }.to_json, headers: { 'Content-Type' => 'application/json' } },
        { status: 200, body: { images: [{ url: image_url_1 }, { url: image_url_2 }] }.to_json, headers: { 'Content-Type' => 'application/json' } }
      )

    stub_request(:get, "#{base_url}/admin/products/#{insales_product_id}.json")
      .to_return(status: 200, body: { product: { id: insales_product_id, permalink: 'test-product' } }.to_json, headers: { 'Content-Type' => 'application/json' })

    storefront_url = "#{base_url}/product/test-product"
    storefront_html = "<img src=\"#{image_url_1}\"><img src=\"#{image_url_2}\">"
    stub_request(:get, storefront_url).to_return(status: 200, body: storefront_html)
    stub_request(:get, image_url_1).to_return(status: 200, body: 'image1')
    stub_request(:get, image_url_2).to_return(status: 200, body: 'image2')

    result = described_class.new.call(product: product, insales_product_id: insales_product_id)

    expect(result.status).to eq('success')
    expect(a_request(:delete, "#{base_url}/admin/products/#{insales_product_id}/images/#{stale_image_id}.json")).to have_been_made.once
  end

  it 'skips media sync when images toggle is disabled' do
    InsalesSetting.first.update!(sync_images_enabled: false)

    result = described_class.new.call(product: product, insales_product_id: insales_product_id)

    expect(result.status).to eq('skipped')
    state = InsalesMediaSyncState.find_by(product_id: product.id)
    expect(state.status).to eq('skipped')
    expect(state.last_error).to eq('images_sync_disabled')
  end
end
