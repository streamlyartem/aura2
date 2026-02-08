# frozen_string_literal: true

module Moysklad
  # Low-level HTTP client for Moysklad API
  class HttpClient
    class Error < StandardError; end
    class RequestError < Error; end
    class NotFoundError < RequestError; end
    class UnauthorizedError < RequestError; end

    attr_reader :config, :connection

    def initialize(config = Config.new)
      @config = config
      @connection = build_connection
    end

    def get(path, params = {})
      response = connection.get(path, params)
      handle_response(response, raise_on_not_found: false)
      response
    end

    def post(path, body = {})
      response = connection.post(path, body)
      handle_response(response)
      response
    end

    def put(path, body = {})
      response = connection.put(path, body)
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
        f.response :logger, Rails.logger, bodies: true
        f.response :json
      end
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
