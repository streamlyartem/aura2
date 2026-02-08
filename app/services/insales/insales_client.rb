# frozen_string_literal: true

require 'faraday'
require 'json'

module Insales
  class InsalesClient
    RETRY_STATUSES = [429].freeze
    RETRY_RANGE = (500..599).freeze
    DEFAULT_MAX_RETRIES = 3
    DEFAULT_OPEN_TIMEOUT = 5
    DEFAULT_TIMEOUT = 15
    MAX_ERROR_BODY_BYTES = 500

    attr_reader :base_url, :login, :password, :connection

    def initialize(base_url: nil, login: nil, password: nil)
      setting = InsalesSetting.first

      @base_url = base_url || setting&.base_url || ENV['INSALES_BASE_URL']
      @login = login || setting&.login || ENV['INSALES_LOGIN']
      @password = password || setting&.password || ENV['INSALES_PASSWORD']
      @connection = build_connection
    end

    def get(path, params = nil)
      request(:get, path, params)
    end

    def post(path, json_body)
      request(:post, path, json_body)
    end

    def put(path, json_body)
      request(:put, path, json_body)
    end

    private

    def build_connection
      Faraday.new(url: base_url) do |f|
        f.request :authorization, :basic, login, password
        f.request :json
        f.response :json, content_type: /\bjson$/
        f.options.open_timeout = DEFAULT_OPEN_TIMEOUT
        f.options.timeout = DEFAULT_TIMEOUT
      end
    end

    def request(method, path, payload)
      attempts = 0

      loop do
        attempts += 1
        response = perform_request(method, path, payload)

        return response if (200..299).cover?(response.status)

        if retryable_status?(response.status) && attempts < DEFAULT_MAX_RETRIES
          sleep retry_delay(attempts)
          next
        end

        log_error(method, path, response)
        return response
      rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
        if attempts < DEFAULT_MAX_RETRIES
          sleep retry_delay(attempts)
          retry
        end

        Rails.logger.error "[InSales] #{method.to_s.upcase} #{path} failed: #{e.class} - #{e.message}"
        raise
      end
    end

    def perform_request(method, path, payload)
      case method
      when :get
        connection.get(path, payload)
      when :post
        connection.post(path, payload)
      when :put
        connection.put(path, payload)
      else
        raise ArgumentError, "Unsupported HTTP method: #{method}"
      end
    end

    def retryable_status?(status)
      RETRY_STATUSES.include?(status) || RETRY_RANGE.cover?(status)
    end

    def retry_delay(attempt)
      0.5 * (2**(attempt - 1))
    end

    def log_error(method, path, response)
      body = response.body
      body_str = if body.is_a?(String)
                   body
                 else
                   JSON.generate(body)
                 end
      body_str = body_str.byteslice(0, MAX_ERROR_BODY_BYTES)
      Rails.logger.warn("[InSales] #{method.to_s.upcase} #{path} -> #{response.status} #{body_str}")
    rescue StandardError
      Rails.logger.warn("[InSales] #{method.to_s.upcase} #{path} -> #{response.status}")
    end
  end
end
