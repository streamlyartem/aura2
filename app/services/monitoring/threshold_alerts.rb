# frozen_string_literal: true

module Monitoring
  class ThresholdAlerts
    ALERT_COOLDOWN = ENV.fetch('MONITORING_ALERT_COOLDOWN_SECONDS', 30.minutes.to_i).to_i.seconds

    class << self
      def check_stock_pipeline!(pending_high:, pending_normal:)
        check_threshold!(
          key: 'stock_pending_high',
          value: pending_high.to_i,
          threshold: ENV.fetch('MONITOR_STOCK_PENDING_HIGH_ALERT', 100).to_i,
          severity: :error,
          message: "Stock events pending high above threshold: #{pending_high}"
        )

        check_threshold!(
          key: 'stock_pending_normal',
          value: pending_normal.to_i,
          threshold: ENV.fetch('MONITOR_STOCK_PENDING_NORMAL_ALERT', 5000).to_i,
          severity: :warning,
          message: "Stock events pending normal above threshold: #{pending_normal}"
        )

        retry_due = StockChangeEvent.pending.where('next_retry_at <= ?', Time.current).count
        check_threshold!(
          key: 'stock_retry_due',
          value: retry_due,
          threshold: ENV.fetch('MONITOR_STOCK_RETRY_DUE_ALERT', 50).to_i,
          severity: :warning,
          message: "Stock events retry due above threshold: #{retry_due}"
        )

        http_429_24h = Rails.cache.read('insales:stock_change_events:http_429').to_i
        check_threshold!(
          key: 'stock_http_429_24h',
          value: http_429_24h,
          threshold: ENV.fetch('MONITOR_STOCK_HTTP_429_24H_ALERT', 20).to_i,
          severity: :warning,
          message: "Stock events HTTP 429 count above threshold: #{http_429_24h}"
        )
      end

      def check_api_v1_runs!
        failed_1h = InsalesApiSyncRun.where('created_at >= ?', 1.hour.ago).where(status: 'failed').count
        check_threshold!(
          key: 'api_v1_failed_runs_1h',
          value: failed_1h,
          threshold: ENV.fetch('MONITOR_API_V1_FAILED_1H_ALERT', 1).to_i,
          severity: :error,
          message: "API v1 failed runs over last hour: #{failed_1h}"
        )
      end

      private

      def check_threshold!(key:, value:, threshold:, severity:, message:)
        return if threshold.negative?

        state_key = "monitoring:alerts:state:#{key}"
        sent_key = "monitoring:alerts:last_sent:#{key}"
        triggered = value >= threshold
        was_triggered = Rails.cache.read(state_key) == true

        if triggered
          last_sent_at = Rails.cache.read(sent_key)
          return if last_sent_at.present? && last_sent_at > ALERT_COOLDOWN.ago

          Monitoring::SentryReporter.report_operational_alert(
            message: message,
            severity: severity,
            tags: { component: 'threshold_alerts', alert_key: key, threshold: threshold },
            extras: { current_value: value, threshold: threshold }
          )
          Rails.cache.write(sent_key, Time.current, expires_in: 2.days)
          Rails.cache.write(state_key, true, expires_in: 2.days)
        elsif was_triggered
          Monitoring::SentryReporter.report_operational_alert(
            message: "Recovered: #{key} back to normal (value=#{value}, threshold=#{threshold})",
            severity: :warning,
            tags: { component: 'threshold_alerts', alert_key: key, recovered: true },
            extras: { current_value: value, threshold: threshold }
          )
          Rails.cache.write(state_key, false, expires_in: 2.days)
          Rails.cache.delete(sent_key)
        end
      end
    end
  end
end
