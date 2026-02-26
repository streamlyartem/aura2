# frozen_string_literal: true

shared_context 'with moysklad products mock' do
  let(:products_json) { file_fixture('moysklad/products.json') }
  let(:products_empty_json) { file_fixture('moysklad/products_empty.json') }

  before do
    stub_request(:get, "#{MoyskladClient::BASE_URL}/entity/product?limit=1000&offset=0")
      .to_return(status: 200, body: products_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, "#{MoyskladClient::BASE_URL}/entity/product?limit=1000&offset=1000")
      .to_return(status: 200, body: products_empty_json, headers: { 'Content-Type' => 'application/json' })
  end
end

shared_context 'with moysklad get product mock' do
  let(:product_json) { file_fixture('moysklad/get_product/200.json') }
  let(:product_not_found_json) { file_fixture('moysklad/get_product/404.json') }
  let(:headers) { { 'Content-Type' => 'application/json' } }

  before do
    stub_request(:get, %r{#{MoyskladClient::BASE_URL}/entity/product/[^/]+})
      .to_return(status: 404, body: product_not_found_json, headers:)
    stub_request(:get, %r{#{MoyskladClient::BASE_URL}/entity/product/#{id_to_stub}})
      .to_return(status: 200, body: product_json, headers:)
  end
end

shared_context 'with moysklad stocks mock' do
  let(:stocks_filtered_by_store_json) { file_fixture('moysklad/stocks_filtered_by_store.json') }

  before do
    stub_request(:get, "#{MoyskladClient::BASE_URL}/report/stock/all?filter=store=https://api.moysklad.ru/api/remap/1.2/entity/store/d2a971ca-9164-11f0-0a80-19cb0021b994&limit=1000&offset=0")
      .to_return(status: 200, body: stocks_filtered_by_store_json, headers: { 'Content-Type' => 'application/json' })
  end
end

shared_context 'with moysklad demand mock' do
  let(:demand_json) { file_fixture('moysklad/demand.json') }

  before do
    stub_request(:post, "#{MoyskladClient::BASE_URL}/entity/demand")
      .to_return(status: 200, body: demand_json, headers: { 'Content-Type' => 'application/json' })
  end
end

shared_context 'with moysklad put product mock' do |success: true|
  let(:put_product_json) { file_fixture('moysklad/put_product/200.json') }
  let(:put_product_error_json) { file_fixture('moysklad/put_product/412.json') }
  let(:put_product_not_found_json) { file_fixture('moysklad/put_product/404.json') }
  let(:headers) { { 'Content-Type' => 'application/json' } }
  let(:pricetype_json) { file_fixture('moysklad/companysettings/pricetype.json') }
  let(:attributes_json) { file_fixture('moysklad/product/metadata/attributes.json') }

  before do
    stub_request(:get, %r{#{MoyskladClient::BASE_URL}/context/companysettings/pricetype})
      .to_return(status: 200, body: pricetype_json, headers:)
    stub_request(:get, %r{#{MoyskladClient::BASE_URL}/entity/product/metadata/attributes})
      .to_return(status: 200, body: attributes_json, headers:)
    stub_request(:put, %r{#{MoyskladClient::BASE_URL}/entity/product/*})
      .to_return(status: 404, body: put_product_not_found_json, headers:)
    if success
      stub_request(:put, %r{#{MoyskladClient::BASE_URL}/entity/product/#{id_to_stub}})
        .to_return(status: 200, body: put_product_json, headers:)
    else
      stub_request(:put, %r{#{MoyskladClient::BASE_URL}/entity/product/#{id_to_stub}})
        .to_return(status: 412, body: put_product_error_json, headers:)
    end
  end
end
