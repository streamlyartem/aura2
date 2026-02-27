# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::ProductFieldCatalog do
  after do
    Rails.cache.delete_matched('insales:product_fields:v*')
    ENV.delete('INSALES_PRODUCT_FIELD_KEYS')
  end

  let(:client) { instance_double(Insales::InsalesClient) }
  let(:catalog) { described_class.new(client) }
  let(:product) do
    create(
      :product,
      path_name: 'Срезы/Светлый/40',
      tone: 'Светлый',
      color: '10',
      length: 40,
      weight: 120,
      structure: 'Прямой',
      ombre: true,
      batch_number: 'B-17',
      retail_price: 120,
      small_wholesale_price: 108,
      large_wholesale_price: 99
    )
  end

  it 'creates missing fields and builds product_field_values_attributes' do
    expect(product.path_name).to eq('Срезы/Светлый/40')
    expect(product.ombre).to eq(true)

    allow(client).to receive(:get).with('/admin/product_fields.json').and_return(
      double(status: 200, body: [])
    )
    allow(client).to receive(:post).with('/admin/product_fields.json', anything) do |_path, payload|
      title = payload.dig(:product_field, :title)
      double(status: 201, body: { 'id' => title.hash.abs % 10_000, 'title' => title })
    end

    values = catalog.product_field_values_attributes(product)

    titles = described_class::DEFAULT_ENABLED_FIELD_KEYS.map do |key|
      described_class::FIELD_DEFINITIONS_BY_KEY.fetch(key).title
    end
    expect(client).to have_received(:post).with('/admin/product_fields.json', hash_including(:product_field)).exactly(titles.size).times
    expect(values).to all(include(:product_field_id, :value))
    expect(values.map { |v| v[:value] }).to include('Срезы', '120', 'Да', '108', '99')
    expect(values.map { |v| v[:value] }).not_to include('Светлый')
    expect(values.map { |v| v[:value] }).not_to include('0-499г: розница; 500-999г: мелкий опт; >=1000г: крупный опт')
  end

  it 'ignores corrupted cache payload and rebuilds field ids safely' do
    Rails.cache.write(catalog.send(:fields_cache_key), true, expires_in: 10.minutes)

    field_rows = described_class::DEFAULT_ENABLED_FIELD_KEYS.each_with_index.map do |key, index|
      definition = described_class::FIELD_DEFINITIONS_BY_KEY.fetch(key)
      { 'id' => index + 1000, 'title' => definition.title }
    end

    allow(client).to receive(:get).with('/admin/product_fields.json').and_return(
      double(status: 200, body: field_rows)
    )
    allow(client).to receive(:post)

    expect { catalog.product_field_values_attributes(product) }.not_to raise_error
    expect(client).to have_received(:get).with('/admin/product_fields.json').at_least(:once)
    expect(client).not_to have_received(:post)
  end

  it 'uses explicit whitelist from env' do
    ENV['INSALES_PRODUCT_FIELD_KEYS'] = 'aura_product_type,aura_structure,aura_price_retail'

    allow(client).to receive(:get).with('/admin/product_fields.json').and_return(
      double(status: 200, body: [])
    )
    allow(client).to receive(:post).with('/admin/product_fields.json', anything) do |_path, payload|
      title = payload.dig(:product_field, :title)
      double(status: 201, body: { 'id' => title.hash.abs % 10_000, 'title' => title })
    end

    values = catalog.product_field_values_attributes(product)
    value_set = values.map { |item| item[:value] }

    expect(value_set).to include('Срезы', 'Прямой', '120')
    expect(value_set).not_to include('Да')
  end
end
