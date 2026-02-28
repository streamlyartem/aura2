# frozen_string_literal: true

return if ENV['SENTRY_DSN'].blank?

Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.environment = ENV.fetch('SENTRY_ENVIRONMENT', Rails.env)
  config.enabled_environments = %w[production staging]
  config.breadcrumbs_logger = %i[active_support_logger http_logger]
  config.send_default_pii = false
  config.traces_sample_rate = ENV.fetch('SENTRY_TRACES_SAMPLE_RATE', 0.05).to_f
  config.profiles_sample_rate = ENV.fetch('SENTRY_PROFILES_SAMPLE_RATE', 0.0).to_f

  # Keep noisy client-side timeouts visible in Sentry, but group them consistently.
  config.before_send = lambda do |event, hint|
    error = hint[:exception]
    next event unless error

    if error.is_a?(Faraday::TimeoutError)
      event.tags[:integration] = 'faraday_timeout'
    elsif error.class.name.start_with?('Net::')
      event.tags[:integration] = 'network'
    end

    event
  end
end
