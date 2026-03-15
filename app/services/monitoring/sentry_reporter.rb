# frozen_string_literal: true

module Monitoring
  class SentryReporter
    class << self
      def report_media_warning(message:, tags: {}, extras: {})
        report(
          domain: 'media',
          component: tags[:component] || 'insales_media_verify',
          severity: :warning,
          message: message,
          tags: tags,
          extras: extras
        )
      end

      def report_stock_error(message:, exception: nil, tags: {}, extras: {})
        report(
          domain: 'stock',
          component: tags[:component] || 'insales_stock_sync',
          severity: :error,
          message: message,
          exception: exception,
          tags: tags,
          extras: extras
        )
      end

      def report_insales_api_error(message:, exception: nil, tags: {}, extras: {})
        report(
          domain: 'insales_api',
          component: tags[:component] || 'insales_client',
          severity: retryable_tag?(tags) ? :warning : :error,
          message: message,
          exception: exception,
          tags: tags,
          extras: extras
        )
      end

      def report_moysklad_api_error(message:, exception: nil, tags: {}, extras: {})
        report(
          domain: 'moysklad_api',
          component: tags[:component] || 'moysklad_http',
          severity: retryable_tag?(tags) ? :warning : :error,
          message: message,
          exception: exception,
          tags: tags,
          extras: extras
        )
      end

      def report_operational_alert(message:, severity: :warning, tags: {}, extras: {})
        report(
          domain: 'operations',
          component: tags[:component] || 'monitoring_alerts',
          severity: severity,
          message: message,
          tags: tags,
          extras: extras
        )
      end

      private

      def report(domain:, component:, severity:, message:, exception: nil, tags: {}, extras: {})
        return unless defined?(Sentry)

        Sentry.with_scope do |scope|
          scope.set_level(severity)
          scope.set_tags(
            {
              domain: domain,
              component: component,
              severity: severity
            }.merge(tags.compact.transform_values(&:to_s))
          )
          scope.set_extras(extras.compact)

          if exception
            Sentry.capture_exception(exception)
          else
            Sentry.capture_message(message)
          end
        end
      rescue StandardError => e
        Rails.logger.warn("[SentryReporter] #{domain}/#{component} failed: #{e.class} - #{e.message}")
      end

      def retryable_tag?(tags)
        tags[:retryable] == true || tags[:retryable].to_s == 'true'
      end
    end
  end
end
