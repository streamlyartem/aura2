# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::AttachProductToCollection do
  let(:client) { instance_double(Insales::InsalesClient) }

  it 'skips create when collect already exists' do
    collects = [{ 'id' => 1, 'collection_id' => 22, 'product_id' => 11 }]
    allow(client).to receive(:collects_by_product).and_return(double(status: 200, body: collects))
    allow(client).to receive(:collect_create)

    result = described_class.new(client).ensure_attached(product_id: 11, collection_id: 22)

    expect(result).to be(true)
    expect(client).not_to have_received(:collect_create)
  end

  it 'creates collect when missing' do
    allow(client).to receive(:collects_by_product).and_return(double(status: 200, body: []))
    allow(client).to receive(:collect_create).and_return(double(status: 201, body: { 'collect' => { 'id' => 9 } }))

    result = described_class.new(client).ensure_attached(product_id: 11, collection_id: 22)

    expect(result).to be(true)
    expect(client).to have_received(:collect_create).with(product_id: 11, collection_id: 22)
  end

  it 'treats conflict as success' do
    allow(client).to receive(:collects_by_product).and_return(double(status: 200, body: []))
    allow(client).to receive(:collect_create).and_return(double(status: 409, body: {}))

    result = described_class.new(client).ensure_attached(product_id: 11, collection_id: 22)

    expect(result).to be(true)
  end
end
