# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insales::SyncProductTriggerJob, type: :job do
  let(:connection) { instance_double(ActiveRecord::ConnectionAdapters::AbstractAdapter) }
  let(:trigger_service) { instance_double(Insales::SyncProductTrigger) }
  let(:result) { instance_double('Result', status: 'success', action: 'publish', message: 'ok') }

  before do
    allow(ActiveRecord::Base.connection_pool).to receive(:with_connection).and_yield(connection)
    allow(trigger_service).to receive(:call).and_return(result)
    allow(Insales::SyncProductTrigger).to receive(:new).and_return(trigger_service)
  end

  it 'runs sync when advisory lock acquired' do
    allow(connection).to receive(:select_value).and_return(true)
    allow(connection).to receive(:execute)

    described_class.perform_now(product_id: 'product-1', reason: 'media_changed')

    expect(trigger_service).to have_received(:call).with(product_id: 'product-1', reason: 'media_changed')
    expect(connection).to have_received(:execute).with(/pg_advisory_unlock/)
  end

  it 'skips sync when advisory lock is not acquired' do
    allow(connection).to receive(:select_value).and_return(false)
    allow(connection).to receive(:execute)

    described_class.perform_now(product_id: 'product-1', reason: 'media_changed')

    expect(trigger_service).not_to have_received(:call)
    expect(connection).not_to have_received(:execute)
  end
end
