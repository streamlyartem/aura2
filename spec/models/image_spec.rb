# frozen_string_literal: true

require 'models/concerns/models_shared_examples'
require 'rails_helper'

RSpec.describe Image do
  it { is_expected.to belong_to(:object).optional }
  it { is_expected.to have_one_attached(:file) }
  it { is_expected.to validate_presence_of(:file) }

  it { is_expected.to delegate_method(:url).to(:file).with_prefix(:service) }

  context 'with file of not permited type' do
    let(:wrong_format_file) { FactoryHelpers.upload_file('spec/support/images/files/wrong_format.php', 'text/php') }
    let(:correct_format_file) { FactoryHelpers.upload_file('spec/support/images/files/borsch.png') }

    it { is_expected.not_to allow_value(wrong_format_file).for(:file) }
    it { is_expected.to allow_value(correct_format_file).for(:file) }
  end

  it_behaves_like 'sets implicit order column', :created_at

  describe '#url' do
    subject(:url) { image.url }

    let(:image) { create(:image) }

    it { is_expected.to eq(Rails.application.routes.url_helpers.rails_blob_url(image.file)) }
  end
end
