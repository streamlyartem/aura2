# frozen_string_literal: true

FactoryBot.define do
  factory :admin_user do
    sequence(:email) { |n| "admin#{n}@example.com" }
    password { SecureRandom.hex(8) }
    allowed_admin_paths { AdminUser::ADMIN_PAGE_OPTIONS.values }
  end
end
