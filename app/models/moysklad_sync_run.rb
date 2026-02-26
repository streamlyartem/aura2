# frozen_string_literal: true

class MoyskladSyncRun < ApplicationRecord
  validates :run_type, presence: true
  validates :status, presence: true

  scope :imports, -> { where(run_type: 'import_products') }
  scope :running, -> { where(status: 'running') }

  def stop_requested?
    stop_requested_at.present?
  end
end
