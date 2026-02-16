# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::ProductFieldCatalog do
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

    titles = described_class::FIELD_DEFINITIONS.map(&:title)
    expect(client).to have_received(:post).with('/admin/product_fields.json', hash_including(:product_field)).exactly(titles.size).times
    expect(values).to all(include(:product_field_id, :value))
    expect(values.map { |v| v[:value] }).to include('Срезы', 'Светлый', 'Да')
    expect(values.map { |v| v[:value] }).to include('0-499г: розница; 500-999г: мелкий опт; >=1000г: крупный опт')
  end
end
