# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuraProducts::TypeResolver do
  describe '#resolve' do
    it 'returns first matching active type by priority' do
      create(:aura_product_type, code: 'piece', name: 'Штучные', priority: 20, matcher_unit_type: 'piece')
      weight = create(:aura_product_type, code: 'srezy', name: 'Срезы', priority: 10, matcher_unit_type: 'weight', matcher_path_prefix: 'Срезы/')

      product = create(:product, unit_type: 'weight', path_name: 'Срезы/Светлый/55')

      resolved = described_class.new.resolve(product)
      expect(resolved&.id).to eq(weight.id)
    end
  end
end
