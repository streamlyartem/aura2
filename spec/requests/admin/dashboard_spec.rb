# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin Dashboard', type: :request do
  let(:admin_user) { create(:admin_user, allowed_admin_paths: AdminUser::ADMIN_PAGE_OPTIONS.values) }

  before do
    sign_in admin_user, scope: :admin_user
  end

  it 'sends test event to Sentry when configured' do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('SENTRY_DSN').and_return('https://example@sentry.io/1')
    allow(Sentry).to receive(:capture_message).and_return('evt-123')

    post '/admin/dashboard/test_sentry'

    expect(response).to have_http_status(:found)
    expect(Sentry).to have_received(:capture_message).with(
      'AURA admin Sentry check',
      hash_including(level: :info, extra: hash_including(source: 'admin_dashboard'))
    )
  end

  it 'does not send test event when Sentry is disabled' do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('SENTRY_DSN').and_return(nil)
    allow(Sentry).to receive(:capture_message)

    post '/admin/dashboard/test_sentry'

    expect(response).to have_http_status(:found)
    expect(Sentry).not_to have_received(:capture_message)
  end
end
