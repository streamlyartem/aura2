# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuraProductType, type: :model do
  describe '#matches?' do
    it 'matches by unit_type and path prefix' do
      type = create(:aura_product_type, matcher_unit_type: 'weight', matcher_path_prefix: 'Срезы/')
      product = create(:product, unit_type: 'weight', path_name: 'Срезы/Светлый/55')

      expect(type.matches?(product)).to eq(true)
    end

    it 'does not match when unit_type differs' do
      type = create(:aura_product_type, matcher_unit_type: 'piece', matcher_path_prefix: 'Срезы/')
      product = create(:product, unit_type: 'weight', path_name: 'Срезы/Светлый/55')

      expect(type.matches?(product)).to eq(false)
    end
  end

  it 'normalizes code before validation' do
    type = described_class.create!(code: '  WeIgHt ', name: 'Весовые товары')

    expect(type.code).to eq('weight')
  end
end
