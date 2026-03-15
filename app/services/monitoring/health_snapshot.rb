# frozen_string_literal: true

module Monitoring
  class HealthSnapshot
    def self.call
      new.call
    end

    def call
      stock_retry_due = StockChangeEvent.pending.where("next_retry_at <= ?", Time.current).count
      stale_processing = StockChangeEvent.stale_processing(Time.current - Insales::StockChangeEvents::Processor::STALE_LOCK_TTL).count

      {
        sentry_enabled: ENV['SENTRY_DSN'].present?,
        stock_events_pending_high: StockChangeEvent.pending.for_priority('high').retry_ready.count,
        stock_events_pending_normal: StockChangeEvent.pending.for_priority('normal').retry_ready.count,
        stock_events_processing: StockChangeEvent.processing.count,
        stock_events_failed: StockChangeEvent.where(status: 'failed').count,
        stock_events_retry_due: stock_retry_due,
        stock_events_stale_processing: stale_processing,
        stock_events_retries_24h: Rails.cache.read("insales:stock_change_events:retries").to_i,
        stock_events_stale_skips_24h: Rails.cache.read("insales:stock_change_events:stale_skips").to_i,
        stock_events_http_429_24h: Rails.cache.read("insales:stock_change_events:http_429").to_i,
        stock_events_p95_seconds: Rails.cache.read("insales:stock_change_events:p95_seconds"),
        outbox_events_total: SyncOutboxEvent.count,
        outbox_events_last_hour: SyncOutboxEvent.where('created_at >= ?', 1.hour.ago).count,
        outbox_last_sequence_id: SyncOutboxEvent.maximum(:id),
        api_v1_runs_last_hour: InsalesApiSyncRun.where('created_at >= ?', 1.hour.ago).count,
        api_v1_runs_failed_last_hour: InsalesApiSyncRun.where('created_at >= ?', 1.hour.ago).where(status: 'failed').count,
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
