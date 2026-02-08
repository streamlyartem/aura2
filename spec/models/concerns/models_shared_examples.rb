# frozen_string_literal: true

RSpec.shared_examples 'sets implicit order column' do |column_name|
  describe '.implicit_order_column' do
    subject(:implicit_order_column) { described_class.implicit_order_column }

    it { is_expected.to eq(column_name) }
  end
end
