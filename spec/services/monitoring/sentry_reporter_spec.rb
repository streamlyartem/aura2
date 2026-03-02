# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Monitoring::SentryReporter do
  let(:scope) { instance_double('Sentry::Scope', set_level: nil, set_tags: nil, set_extras: nil) }

  before do
    stub_const('Sentry', class_double('Sentry').as_stubbed_const)
    allow(Sentry).to receive(:with_scope).and_yield(scope)
    allow(Sentry).to receive(:capture_message)
    allow(Sentry).to receive(:capture_exception)
  end

  it 'reports media warning with normalized tags' do
    described_class.report_media_warning(
      message: 'media mismatch',
      tags: { component: 'insales_media_verify', retryable: true },
      extras: { product_id: '123' }
    )

    expect(scope).to have_received(:set_level).with(:warning)
    expect(scope).to have_received(:set_tags).with(
      hash_including(
        domain: 'media',
        component: 'insales_media_verify',
        severity: :warning,
        retryable: 'true'
      )
    )
    expect(scope).to have_received(:set_extras).with(hash_including(product_id: '123'))
    expect(Sentry).to have_received(:capture_message).with('media mismatch')
  end

  it 'reports stock exception as error' do
    error = StandardError.new('boom')

    described_class.report_stock_error(
      message: 'stock failed',
      exception: error,
      tags: { component: 'insales_stock_sync' },
      extras: { product_id: '456' }
    )

    expect(scope).to have_received(:set_level).with(:error)
    expect(scope).to have_received(:set_tags).with(
      hash_including(
        domain: 'stock',
        component: 'insales_stock_sync',
        severity: :error
      )
    )
    expect(scope).to have_received(:set_extras).with(hash_including(product_id: '456'))
    expect(Sentry).to have_received(:capture_exception).with(error)
  end
end
