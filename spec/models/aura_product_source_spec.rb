# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuraProductSource, type: :model do
  it 'parses settings from json string' do
    source = described_class.create!(
      code: 'moysklad-main',
      name: 'МойСклад основной',
      source_kind: 'moysklad',
      settings: '{"api_base":"https://api.moysklad.ru"}'
    )

    expect(source.settings).to eq('api_base' => 'https://api.moysklad.ru')
  end

  it 'adds validation error for invalid json settings' do
    source = described_class.new(code: 'bad', name: 'Bad', source_kind: 'moysklad', settings: '{oops}')

    expect(source.valid?).to eq(false)
    expect(source.errors[:settings]).to include('должен быть валидным JSON')
  end
end
