# frozen_string_literal: true

FactoryBot.define do
  factory :image do
    file { FactoryHelpers.upload_file('spec/support/images/files/borsch.png') }
  end
end
