# frozen_string_literal: true

module Monitoring
  class HealthSnapshot
    def self.call
      new.call
    end

    def call
      {
        sentry_enabled: ENV['SENTRY_DSN'].present?,
        stock_events_pending_high: StockChangeEvent.pending.for_priority('high').retry_ready.count,
        stock_events_pending_normal: StockChangeEvent.pending.for_priority('normal').retry_ready.count,
        stock_events_processing: StockChangeEvent.processing.count,
        stock_events_failed: StockChangeEvent.where(status: 'failed').count,
        stale_insales_sync_runs: InsalesSyncRun.stale_running_scope.count,
        insales_failed_jobs: SolidQueue::FailedExecution.joins(:job).where(solid_queue_jobs: { class_name: 'Insales::SyncProductStocksJob' }).count,
        moysklad_failed_jobs: SolidQueue::FailedExecution.joins(:job).where(solid_queue_jobs: { class_name: 'Moysklad::ImportProductsJob' }).count,
        failed_jobs_last_24h: SolidQueue::FailedExecution.where('created_at >= ?', 24.hours.ago).count,
        p95_insales_sync_seconds: p95_insales_sync_seconds
      }
    end

    private

    def p95_insales_sync_seconds
      samples = InsalesSyncRun
                .where.not(started_at: nil, finished_at: nil)
                .where('finished_at >= ?', 24.hours.ago)
                .order(finished_at: :desc)
                .limit(200)
                .pluck(:started_at, :finished_at)
                .map { |started_at, finished_at| finished_at - started_at }
                .select(&:positive?)

      return nil if samples.empty?

      sorted = samples.sort
      rank = [(sorted.length * 0.95).ceil - 1, 0].max
      sorted[rank].round(2)
    end
  end
end
