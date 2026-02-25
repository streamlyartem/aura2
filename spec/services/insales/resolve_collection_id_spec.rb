# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::ResolveCollectionId do
  let(:client) { instance_double(Insales::InsalesClient) }

  it 'resolves existing collection without autocreate' do
    collections = [
      { 'id' => 10, 'title' => 'Каталог', 'parent_id' => nil },
      { 'id' => 1, 'title' => 'Срезы', 'parent_id' => 10 },
      { 'id' => 2, 'title' => 'Светлый', 'parent_id' => 1 }
    ]
    allow(client).to receive(:collections_all).and_return(double(status: 200, body: collections))

    resolver = described_class.new(client)
    id = resolver.resolve('Срезы/Светлый', autocreate: false)

    expect(id).to eq(2)
    status = InsalesCategoryStatus.find_by(aura_path: 'Срезы/Светлый')
    expect(status.sync_status).to eq('ok')
    expect(status.insales_collection_id).to eq(2)
  end

  it 'resolves when collections include root Каталог but path omits it' do
    collections = [
      { 'id' => 10, 'title' => 'Каталог', 'parent_id' => nil },
      { 'id' => 11, 'title' => 'Срезы', 'parent_id' => 10 },
      { 'id' => 12, 'title' => 'Светлый', 'parent_id' => 11 },
      { 'id' => 13, 'title' => '55', 'parent_id' => 12 }
    ]
    allow(client).to receive(:collections_all).and_return(double(status: 200, body: collections))

    resolver = described_class.new(client)
    id = resolver.resolve('Срезы/Светлый/55', autocreate: false)

    expect(id).to eq(13)
    status = InsalesCategoryStatus.find_by(aura_path: 'Срезы/Светлый/55')
    expect(status.sync_status).to eq('ok')
    expect(status.insales_collection_id).to eq(13)
  end

  it 'resolves via manual mapping override first' do
    mapping = InsalesCategoryMapping.create!(
      aura_key_type: 'path',
      aura_key: 'Срезы/Светлый',
      insales_category_id: 99,
      insales_collection_title: 'Светлый',
      is_active: true
    )

    allow(client).to receive(:collections_all).and_return(double(status: 200, body: []))

    resolver = described_class.new(client)
    id = resolver.resolve('Срезы/Светлый', autocreate: false)

    expect(id).to eq(99)
    expect(mapping.reload.insales_category_id).to eq(99)
  end

  it 'creates missing collections when autocreate is enabled' do
    allow(client).to receive(:collections_all).and_return(double(status: 200, body: []))
    allow(client).to receive(:collection_create)
      .with(title: 'Срезы', parent_id: nil)
      .and_return(double(status: 201, body: { 'collection' => { 'id' => 10, 'title' => 'Срезы', 'parent_id' => nil } }))
    allow(client).to receive(:collection_create)
      .with(title: 'Светлый', parent_id: 10)
      .and_return(double(status: 201, body: { 'collection' => { 'id' => 11, 'title' => 'Светлый', 'parent_id' => 10 } }))

    resolver = described_class.new(client)
    id = resolver.resolve('Срезы/Светлый', autocreate: true)

    expect(id).to eq(11)
    status = InsalesCategoryStatus.find_by(aura_path: 'Срезы/Светлый')
    expect(status.sync_status).to eq('ok')
    expect(status.insales_collection_id).to eq(11)
  end
end
