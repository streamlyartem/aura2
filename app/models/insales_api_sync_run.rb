# frozen_string_literal: true

class InsalesApiSyncRun < ApplicationRecord
  STATUSES = %w[queued running success failed].freeze
  RUN_TYPES = %w[upsert full_sync].freeze

  validates :run_type, presence: true, inclusion: { in: RUN_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }

  def summary
    {
      created: created_count,
      updated: updated_count,
      unchanged: unchanged_count,
      skipped: skipped_count,
      failed: failed_count
    }
  end
end
