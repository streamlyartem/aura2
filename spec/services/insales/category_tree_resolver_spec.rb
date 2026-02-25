# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::CategoryTreeResolver do
  let(:client) { instance_double(Insales::InsalesClient) }

  it 'resolves category id by path' do
    categories = [
      { 'id' => 1, 'title' => 'Срезы', 'parent_id' => nil },
      { 'id' => 2, 'title' => 'Светлый', 'parent_id' => 1 },
      { 'id' => 3, 'title' => '55', 'parent_id' => 2 }
    ]
    allow(client).to receive(:get).with('/admin/categories.json')
      .and_return(double(status: 200, body: { 'categories' => categories }))

    resolver = described_class.new(client)

    expect(resolver.category_id_for_path('Срезы/Светлый/55')).to eq(3)
  end

  it 'returns nil when path not found' do
    allow(client).to receive(:get).with('/admin/categories.json')
      .and_return(double(status: 200, body: { 'categories' => [] }))

    resolver = described_class.new(client)

    expect(resolver.category_id_for_path('Срезы/Светлый/55')).to be_nil
  end
end
