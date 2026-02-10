# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MoyskladSyncRun, type: :model do
  it 'requires run_type and status' do
    record = described_class.new
    expect(record).not_to be_valid
    expect(record.errors[:run_type]).to be_present
    expect(record.errors[:status]).to be_present
  end
end
