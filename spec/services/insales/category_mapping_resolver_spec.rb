# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::CategoryMappingResolver do
  it 'picks the most specific mapping for a product' do
    create(:product, path_name: 'Срезы/Светлый/55', tone: 'Светлый', length: 55, ombre: true, structure: 'Прямой')

    InsalesCategoryMapping.create!(product_type: 'Срезы', insales_category_id: 100)
    InsalesCategoryMapping.create!(product_type: 'Срезы', tone: 'Светлый', insales_category_id: 200)
    InsalesCategoryMapping.create!(product_type: 'Срезы', tone: 'Светлый', length: 55, insales_category_id: 300)
    InsalesCategoryMapping.create!(product_type: 'Срезы', tone: 'Светлый', length: 55, ombre: true, insales_category_id: 400)

    product = Product.last
    resolver = described_class.new

    expect(resolver.category_id_for(product)).to eq(400)
  end

  it 'returns nil when no mapping matches' do
    product = create(:product, path_name: 'Ленты/Темный/50', tone: 'Темный', length: 50)

    resolver = described_class.new

    expect(resolver.category_id_for(product)).to be_nil
  end
end
