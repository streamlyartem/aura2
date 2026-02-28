# frozen_string_literal: true

class InsalesSyncRun < ApplicationRecord
  self.implicit_order_column = :created_at

  STALE_TTL = 45.minutes

  scope :running, -> { where(status: 'running', finished_at: nil) }

  validates :store_name, presence: true
  validates :status, presence: true

  def self.recover_stale_runs!(ttl: STALE_TTL, message: 'Recovered stale run (no active SolidQueue execution)')
    return 0 if sync_job_claimed?

    stale_running_scope(ttl:)
      .update_all(status: 'stopped', finished_at: Time.current, last_error: message, updated_at: Time.current)
  end

  def self.stale_running_scope(ttl: STALE_TTL)
    threshold = ttl.ago

    running
      .where('COALESCE(started_at, created_at) < ?', threshold)
      .where('COALESCE(updated_at, created_at) < ?', threshold)
      .where('COALESCE(processed, 0) = 0')
  end

  def self.sync_job_claimed?
    SolidQueue::ClaimedExecution
      .joins(:job)
      .where(solid_queue_jobs: { class_name: 'Insales::SyncProductStocksJob' })
      .exists?
  rescue StandardError
    false
  end
end
