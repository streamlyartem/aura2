# frozen_string_literal: true

class MoyskladSyncRun < ApplicationRecord
  validates :run_type, presence: true
  validates :status, presence: true
end
