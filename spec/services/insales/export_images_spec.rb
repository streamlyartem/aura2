# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::ExportImages do
  let(:client) { instance_double(Insales::InsalesClient) }

  it 'skips image when blob is missing and does not count it as hard error' do
    product = create(:product)
    image = create(:image, object: product)
    InsalesProductMapping.create!(aura_product_id: product.id, insales_product_id: 123, insales_variant_id: 456)

    allow_any_instance_of(ActiveStorage::Blob).to receive(:download).and_raise(ActiveStorage::FileNotFoundError)
    allow(client).to receive(:post)

    result = described_class.new(client).call(product_id: product.id, dry_run: false)

    expect(result.processed).to eq(1)
    expect(result.uploaded).to eq(0)
    expect(result.skipped).to eq(1)
    expect(result.errors).to eq(0)
    expect(client).not_to have_received(:post)
  end
end
