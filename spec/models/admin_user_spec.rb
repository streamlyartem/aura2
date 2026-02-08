# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdminUser do
  it { is_expected.to validate_presence_of(:email) }
  it { is_expected.to validate_uniqueness_of(:reset_password_token).allow_nil }
end
