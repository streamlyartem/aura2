# frozen_string_literal: true

module Insales
  module StockChangeEvents
    class Metrics
      LATENCIES_CACHE_KEY = "insales:stock_change_events:latencies_seconds"
      LATENCIES_LIMIT = 300

      class << self
        def report_queue_depth!
          high = StockChangeEvent.pending.for_priority("high").retry_ready.count
          normal = StockChangeEvent.pending.for_priority("normal").retry_ready.count

          Rails.cache.write("insales:stock_change_events:pending_high", high, expires_in: 2.hours)
          Rails.cache.write("insales:stock_change_events:pending_normal", normal, expires_in: 2.hours)
          Rails.logger.info("[InSales][StockEvents][Metrics] pending_high=#{high} pending_normal=#{normal}")
        end

        def track_retry!
          increment_counter!("insales:stock_change_events:retries")
        end

        def track_stale_skip!
          increment_counter!("insales:stock_change_events:stale_skips")
        end

        def track_sync_latency!(seconds)
          return if seconds.blank?

          latencies = Array(Rails.cache.read(LATENCIES_CACHE_KEY))
          latencies << seconds.to_f
          latencies = latencies.last(LATENCIES_LIMIT)
          Rails.cache.write(LATENCIES_CACHE_KEY, latencies, expires_in: 24.hours)

          p95 = percentile(latencies, 95)
          Rails.cache.write("insales:stock_change_events:p95_seconds", p95, expires_in: 24.hours)
          Rails.logger.info("[InSales][StockEvents][Metrics] latency=#{seconds.round(3)}s p95=#{p95.round(3)}s")
        end

        private

        def increment_counter!(key)
          value = Rails.cache.read(key).to_i + 1
          Rails.cache.write(key, value, expires_in: 24.hours)
        end

        def percentile(values, p)
          return 0.0 if values.empty?

          sorted = values.sort
          rank = ((p / 100.0) * (sorted.length - 1)).round
          sorted[rank]
        end
      end
    end
  end
end
