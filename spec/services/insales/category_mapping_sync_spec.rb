# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::CategoryMappingSync do
  let(:client) { instance_double(Insales::InsalesClient) }

  it 'creates mappings for Sрезы tree' do
    categories = [
      { 'id' => 1, 'title' => 'Срезы', 'parent_id' => nil },
      { 'id' => 2, 'title' => 'Светлый', 'parent_id' => 1 },
      { 'id' => 3, 'title' => '55', 'parent_id' => 2 },
      { 'id' => 4, 'title' => 'Ленты', 'parent_id' => nil }
    ]
    allow(client).to receive(:get).with('/admin/categories.json')
      .and_return(double(status: 200, body: { 'categories' => categories }))

    result = described_class.new(client).call

    expect(result.created).to eq(3)
    expect(InsalesCategoryMapping.where(product_type: 'Срезы').count).to eq(3)
    expect(InsalesCategoryMapping.find_by(product_type: 'Срезы', tone: 'Светлый', length: 55).insales_category_id).to eq(3)
  end
end
