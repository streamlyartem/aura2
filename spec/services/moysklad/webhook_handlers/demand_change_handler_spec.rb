# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Moysklad::WebhookHandlers::DemandChangeHandler do
  it 'imports stocks on demand webhook' do
    event = {
      'meta' => { 'type' => 'demand', 'href' => 'https://api.moysklad.ru/api/remap/1.2/entity/demand/1' },
      'action' => 'CREATE'
    }

    sync = instance_double(MoyskladSync)
    allow(MoyskladSync).to receive(:new).and_return(sync)
    allow(sync).to receive(:import_stocks).and_return([])

    described_class.new(event).handle

    expect(sync).to have_received(:import_stocks)
  end
end
