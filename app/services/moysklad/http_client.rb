# frozen_string_literal: true

module Moysklad
  # Low-level HTTP client for Moysklad API
  class HttpClient
    class Error < StandardError; end
    class RequestError < Error; end
    class NotFoundError < RequestError; end
    class UnauthorizedError < RequestError; end

    DEFAULT_OPEN_TIMEOUT = 5
    DEFAULT_TIMEOUT = 120
    MAX_RETRIES = 3
    RETRYABLE_STATUSES = [429, 500, 502, 503, 504].freeze

    attr_reader :config, :connection

    def initialize(config = Config.new)
      @config = config
      @connection = build_connection
    end

    def get(path, params = {})
      response = with_retries { connection.get(path, params) }
      handle_response(response, raise_on_not_found: false)
      response
    end

    def post(path, body = {})
      response = with_retries { connection.post(path, body) }
      handle_response(response)
      response
    end

    def put(path, body = {})
      response = with_retries { connection.put(path, body) }
      handle_response(response)
      response
    end

    def get_full(url)
      # If URL is absolute, extract path relative to base URL
      if url.start_with?('http')
        uri = URI.parse(url)
        base_uri = URI.parse(config.base_url || Moysklad::Config::BASE_URL)

        # Remove base URL path from the full URL path
        path = uri.path
        base_path = base_uri.path
        path = path[base_path.length..] if path.start_with?(base_path)

        # Remove leading slash and add query string if present
        path = path.gsub(%r{^/}, '')
        query = uri.query
        full_path = query ? "#{path}?#{query}" : path
        get(full_path)
      else
        get(url)
      end
    end

    private

    def build_connection
      base_url = config.base_url || Moysklad::Config::BASE_URL
      Faraday.new(url: base_url) do |f|
        f.request :json
        # Only add authentication if credentials are provided
        f.request :authorization, :basic, config.username, config.password if config.username && config.password
        f.response :logger, Rails.logger, bodies: ENV['MOYSKLAD_HTTP_DEBUG'].to_s == '1'
        f.response :json
        f.options.open_timeout = DEFAULT_OPEN_TIMEOUT
        f.options.timeout = DEFAULT_TIMEOUT
      end
    end

    def with_retries
      attempts = 0

      loop do
        attempts += 1
        response = yield
        return response unless retryable_status?(response.status) && attempts < MAX_RETRIES

        sleep retry_delay(attempts, response.status)
      rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Net::ReadTimeout => e
        raise e unless attempts < MAX_RETRIES

        Rails.logger.warn("[Moysklad] request retry=#{attempts} error=#{e.class}: #{e.message}")
        sleep retry_delay(attempts, nil)
      end
    end

    def retryable_status?(status)
      RETRYABLE_STATUSES.include?(status.to_i)
    end

    def retry_delay(attempt, status)
      return 2.0 if status.to_i == 429

      0.5 * (2**(attempt - 1))
    end

    def handle_response(response, raise_on_not_found: true)
      # Don't raise exceptions for successful responses
      return if (200..299).cover?(response.status)

      case response.status
      when 401
        raise UnauthorizedError, 'Moysklad API authentication failed'
      when 404
        raise NotFoundError, "Resource not found: #{response.env.url}" if raise_on_not_found
      when 400..499
        raise RequestError, "Client error: #{response.status} - #{response.body}"
      when 500..599
        raise RequestError, "Server error: #{response.status} - #{response.body}"
      end
    end
  end
end
