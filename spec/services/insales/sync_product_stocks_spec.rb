# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::SyncProductStocks do
  let(:base_url) { 'https://example.myinsales.ru' }
  let(:login) { 'user' }
  let(:password) { 'pass' }

  before do
    @previous_export_fields = ENV['INSALES_EXPORT_PRODUCT_FIELDS']
    ENV['INSALES_EXPORT_PRODUCT_FIELDS'] = '0'

    InsalesSetting.create!(
      base_url: base_url,
      login: login,
      password: password,
      category_id: '777',
      default_collection_id: '999',
      image_url_mode: 'service_url',
      allowed_store_names: ['Тест']
    )
  end

  after do
    ENV['INSALES_EXPORT_PRODUCT_FIELDS'] = @previous_export_fields
  end

  it 'syncs one product and verifies' do
    product = create(:product, name: 'Sync Product', sku: 'SKU-3000', retail_price: 19.0)
    zero_product = create(:product, name: 'Zero Stock', sku: 'SKU-3001', retail_price: 10.0)
    negative_product = create(:product, name: 'Negative Stock', sku: 'SKU-3002', retail_price: 10.0)
    create(:product_stock, product: product, stock: 2, store_name: 'Тест')
    create(:product_stock, product: zero_product, stock: 0, store_name: 'Тест')
    create(:product_stock, product: negative_product, stock: -1, store_name: 'Тест')
    InsalesCatalogItem.create!(
      product: product,
      export_quantity: 1,
      prices_cents: { 'retail' => 1900 },
      status: 'ready',
      prepared_at: Time.current
    )
    InsalesProductMapping.create!(
      aura_product_id: product.id,
      insales_product_id: 10,
      insales_variant_id: 55
    )

    stub_request(:put, "#{base_url}/admin/products/10.json")
      .with(basic_auth: [login, password])
      .to_return(status: 200, body: { product: { id: 10 } }.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:put, "#{base_url}/admin/variants/55.json")
      .with(basic_auth: [login, password])
      .to_return(status: 200, body: { variant: { id: 55 } }.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:post, "#{base_url}/admin/collections/999/products.json")
      .with(basic_auth: [login, password])
      .to_return(status: 200, body: {}.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:put, "#{base_url}/admin/products/variants_group_update.json")
      .with(basic_auth: [login, password])
      .to_return(status: 200, body: {}.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:get, "#{base_url}/admin/products/10.json")
      .with(basic_auth: [login, password])
      .to_return(
        status: 200,
        body: {
          product: {
            id: 10,
            title: 'Sync Product',
            category_id: 777,
            collection_ids: [999],
            variants: [{ id: 55, sku: 'SKU-3000' }]
          }
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    stub_request(:get, "#{base_url}/admin/variants/55.json")
      .with(basic_auth: [login, password])
      .to_return(
        status: 200,
        body: { variant: { id: 55, sku: 'SKU-3000', price: 19.0, quantity: 2 } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    allow_any_instance_of(Insales::SyncProductMedia).to receive(:call)
      .and_return(
        double(
          status: 'success',
          last_error: nil,
          photos_uploaded: 0,
          photos_errors: 0,
          photos_skipped: 0,
          verified_admin: true,
          verified_storefront: true
        )
      )

    verify_product = instance_double(Insales::VerifyProduct)
    allow(Insales::VerifyProduct).to receive(:new).and_return(verify_product)
    allow(verify_product).to receive(:call)
      .and_return(double(ok: true, message: nil))

    expect(Insales::ExportProducts).to receive(:call)
      .with(product_id: product.id, dry_run: false)
      .and_return(Insales::ExportProducts::Result.new(processed: 1, created: 0, updated: 1, errors: 0))
    expect(Insales::ExportProducts).not_to receive(:call)
      .with(product_id: zero_product.id, dry_run: false)
    expect(Insales::ExportProducts).not_to receive(:call)
      .with(product_id: negative_product.id, dry_run: false)

    result = described_class.new.call(store_names: ['Тест'])

    expect(result.processed).to eq(1)
    expect(result.errors).to eq(0), "last_error_message=#{result.last_error_message.inspect}"
    expect(result.verify_failures).to eq(0)
    expect(verify_product).to have_received(:call).with(
      hash_including(
        product: product,
        expected_category_id: nil,
        expected_price: 19.0,
        expected_quantity: 1
      )
    )
  end

  it 'skips products without prepared catalog row without counting hard error' do
    product = create(:product, name: 'No Catalog Item', sku: 'SKU-4040')
    create(:product_stock, product: product, stock: 5, store_name: 'Тест')

    expect(Insales::ExportProducts).not_to receive(:call)

    result = described_class.new.call(store_names: ['Тест'])

    expect(result.processed).to eq(1)
    expect(result.errors).to eq(0)
    expect(result.created).to eq(0)
    expect(result.updated).to eq(0)
  end

  it 'treats media verify issues as warnings and continues sync' do
    product = create(:product, name: 'Media Warning', sku: 'SKU-7777', retail_price: 19.0)
    create(:product_stock, product: product, stock: 2, store_name: 'Тест')
    InsalesCatalogItem.create!(
      product: product,
      export_quantity: 1,
      prices_cents: { 'retail' => 1900 },
      status: 'ready',
      prepared_at: Time.current
    )
    InsalesProductMapping.create!(
      aura_product_id: product.id,
      insales_product_id: 10,
      insales_variant_id: 55
    )

    stub_request(:put, "#{base_url}/admin/products/10.json")
      .to_return(status: 200, body: { product: { id: 10 } }.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:put, "#{base_url}/admin/variants/55.json")
      .to_return(status: 200, body: { variant: { id: 55 } }.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:post, "#{base_url}/admin/collections/999/products.json")
      .to_return(status: 200, body: {}.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:put, "#{base_url}/admin/products/variants_group_update.json")
      .to_return(status: 200, body: {}.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, "#{base_url}/admin/products/10.json")
      .to_return(
        status: 200,
        body: {
          product: {
            id: 10,
            title: 'Media Warning',
            category_id: 777,
            collection_ids: [999],
            variants: [{ id: 55, sku: 'SKU-7777' }]
          }
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    stub_request(:get, "#{base_url}/admin/variants/55.json")
      .to_return(
        status: 200,
        body: { variant: { id: 55, sku: 'SKU-7777', price: 19.0, quantity: 1 } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    allow_any_instance_of(Insales::SyncProductMedia).to receive(:call)
      .and_return(
        double(
          status: 'in_progress',
          last_error: 'processing: Admin images count 0 < expected 2',
          photos_in_aura: 2,
          photos_uploaded: 0,
          photos_errors: 0,
          photos_skipped: 0,
          verified_admin: false,
          verified_storefront: false
        )
      )

    verify_product = instance_double(Insales::VerifyProduct)
    allow(Insales::VerifyProduct).to receive(:new).and_return(verify_product)
    allow(verify_product).to receive(:call)
      .and_return(double(ok: true, message: nil))

    expect(Monitoring::SentryReporter).to receive(:report_media_warning).with(
      hash_including(
        message: 'InSales media verify warning',
        tags: hash_including(component: 'insales_media_verify'),
        extras: hash_including(
          product_id: product.id,
          sku: 'SKU-7777',
          media_error: 'processing: Admin images count 0 < expected 2'
        )
      )
    )

    allow(Insales::ExportProducts).to receive(:call)
      .and_return(Insales::ExportProducts::Result.new(processed: 1, created: 0, updated: 1, errors: 0))

    result = described_class.new.call(store_names: ['Тест'])

    expect(result.processed).to eq(1)
    expect(result.errors).to eq(0)
    expect(result.verify_failures).to eq(1)
    expect(result.last_error_message).to eq('processing: Admin images count 0 < expected 2')
  end
end
