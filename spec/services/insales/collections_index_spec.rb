# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::CollectionsIndex do
  it 'builds full paths and index' do
    collections = [
      { 'id' => 1, 'title' => 'Срезы', 'parent_id' => nil },
      { 'id' => 2, 'title' => 'Светлый', 'parent_id' => 1 },
      { 'id' => 3, 'title' => '55', 'parent_id' => 2 }
    ]

    index = described_class.new.build_index(collections)

    expect(index.by_id[1]['title']).to eq('Срезы')
    expect(index.children_by_parent_id[nil].map { |c| c['id'] }).to contain_exactly(1)
    expect(index.by_full_path['Срезы/Светлый/55']['id']).to eq(3)
  end
end
