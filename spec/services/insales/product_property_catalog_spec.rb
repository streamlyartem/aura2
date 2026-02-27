# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::ProductPropertyCatalog do
  describe '#properties_attributes' do
    it 'builds only whitelist properties and updates existing by id' do
      product = build(
        :product,
        path_name: 'Срезы/Светлый/55',
        tone: 'Светлый',
        color: '10',
        length: 55.0,
        weight: 106.0,
        ombre: true,
        structure: 'Волна'
      )

      result = described_class.new.properties_attributes(
        product,
        existing_properties: [
          { 'id' => 11, 'title' => 'Тип товара', 'characteristics' => ['Старое'] },
          { 'id' => 12, 'title' => 'Неподдерживаемое', 'characteristics' => ['X'] }
        ]
      )

      expect(result).to eq(
        [
          { id: 11, title: 'Тип товара', value: 'Срезы' },
          { title: 'Тон', value: 'Светлый' },
          { title: 'Цвет', value: '10' },
          { title: 'Длина (см)', value: '55' },
          { title: 'Вес (г)', value: '106' },
          { title: 'Омбре', value: 'Да' },
          { title: 'Структура', value: 'Волна' }
        ]
      )
    end

    it 'returns ombre as Нет and skips blank optional values' do
      product = build(
        :product,
        path_name: nil,
        tone: '',
        color: nil,
        length: nil,
        weight: nil,
        ombre: false,
        structure: ''
      )

      result = described_class.new.properties_attributes(product)

      expect(result).to eq([{ title: 'Омбре', value: 'Нет' }])
    end
  end
end
