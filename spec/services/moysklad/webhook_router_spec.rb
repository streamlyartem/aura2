# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Moysklad::WebhookRouter do
  describe '.handler_for' do
    it 'routes demand events to demand handler' do
      expect(described_class.handler_for('demand', 'CREATE')).to eq(Moysklad::WebhookHandlers::DemandChangeHandler)
      expect(described_class.handler_for('demand', 'UPDATE')).to eq(Moysklad::WebhookHandlers::DemandChangeHandler)
      expect(described_class.handler_for('demand', 'DELETE')).to eq(Moysklad::WebhookHandlers::DemandChangeHandler)
    end
  end
end
