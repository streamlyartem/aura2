# frozen_string_literal: true

module ExternalHttpConfig
  module_function

  def open_timeout(service, default:)
    fetch_numeric(service, 'OPEN_TIMEOUT', default)
  end

  def read_timeout(service, default:)
    fetch_numeric(service, 'READ_TIMEOUT', default)
  end

  def write_timeout(service, default:)
    fetch_numeric(service, 'WRITE_TIMEOUT', default)
  end

  def max_retries(service, default:)
    fetch_numeric(service, 'MAX_RETRIES', default).to_i
  end

  def apply_faraday!(options, service:, open_timeout:, read_timeout:, write_timeout: read_timeout)
    options.open_timeout = self.open_timeout(service, default: open_timeout)
    options.timeout = self.read_timeout(service, default: read_timeout)
    options.write_timeout = self.write_timeout(service, default: write_timeout) if options.respond_to?(:write_timeout=)
  end

  def apply_net_http!(http, service:, open_timeout:, read_timeout:, write_timeout: read_timeout)
    http.open_timeout = self.open_timeout(service, default: open_timeout)
    http.read_timeout = self.read_timeout(service, default: read_timeout)
    http.write_timeout = self.write_timeout(service, default: write_timeout) if http.respond_to?(:write_timeout=)
    http
  end

  def fetch_numeric(service, suffix, default)
    raw = ENV[service_key(service, suffix)].presence || ENV[global_key(suffix)].presence
    return default unless raw

    Float(raw)
  rescue ArgumentError, TypeError
    default
  end

  def service_key(service, suffix)
    "#{service.to_s.upcase}_HTTP_#{suffix}"
  end

  def global_key(suffix)
    "HTTP_#{suffix}"
  end
end
