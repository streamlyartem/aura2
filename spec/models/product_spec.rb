# frozen_string_literal: true

require 'models/concerns/models_shared_examples'
require 'rails_helper'

RSpec.describe Product do
  it { is_expected.to have_many(:images).dependent(:destroy) }

  it_behaves_like 'sets implicit order column', :created_at
end
