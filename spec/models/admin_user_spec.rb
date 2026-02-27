# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdminUser do
  it { is_expected.to validate_presence_of(:email) }
  it { is_expected.to validate_uniqueness_of(:reset_password_token).allow_nil }
  it { is_expected.to validate_presence_of(:allowed_admin_paths) }

  describe '#can_access_admin_path?' do
    it 'allows only selected pages' do
      admin = build(:admin_user, allowed_admin_paths: ['/admin/dashboard'])

      expect(admin.can_access_admin_path?('/admin/dashboard')).to eq(true)
      expect(admin.can_access_admin_path?('/admin/products')).to eq(false)
    end

    it 'normalizes saved paths before checks' do
      admin = build(:admin_user, allowed_admin_paths: ['admin/products/'])
      admin.valid?

      expect(admin.allowed_admin_paths).to eq(['/admin/products'])
      expect(admin.can_access_admin_path?('/admin/products')).to eq(true)
    end
  end
end
