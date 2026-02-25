# frozen_string_literal: true

require 'faraday'
require 'json'
require 'net/http'
require 'securerandom'

module Insales
  class InsalesClient
    MultipartResponse = Struct.new(:status, :body, keyword_init: true)
    RETRY_STATUSES = [429].freeze
    RETRY_RANGE = (500..599).freeze
    DEFAULT_MAX_RETRIES = 5
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

    def delete(path, params = nil)
      request(:delete, path, params)
    end

    def post_multipart(path, fields:, file_field_name:, filename:, content_type:, file_bytes:)
      uri = build_uri(path)
      boundary = "----RubyMultipart#{SecureRandom.hex(12)}"
      body = build_multipart_body(boundary, fields, file_field_name, filename, content_type, file_bytes)

      request = Net::HTTP::Post.new(uri.request_uri)
      request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
      request.basic_auth(login, password)
      request.body = body

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.request(request)
      end

      MultipartResponse.new(status: response.code.to_i, body: response.body)
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

    def build_uri(path)
      base = base_url.to_s
      base = "https://#{base}" unless base.start_with?('http')
      URI.join(base.end_with?('/') ? base : "#{base}/", path.sub(%r{^/}, ''))
    end

    def build_multipart_body(boundary, fields, file_field_name, filename, content_type, file_bytes)
      body = +''

      fields.each do |name, value|
        body << "--#{boundary}\r\n"
        body << "Content-Disposition: form-data; name=\"#{name}\"\r\n\r\n"
        body << value.to_s
        body << "\r\n"
      end

      body << "--#{boundary}\r\n"
      body << "Content-Disposition: form-data; name=\"#{file_field_name}\"; filename=\"#{filename}\"\r\n"
      body << "Content-Type: #{content_type}\r\n\r\n"
      body << file_bytes
      body << "\r\n"
      body << "--#{boundary}--\r\n"
      body
    end

    def request(method, path, payload)
      attempts = 0

      loop do
        attempts += 1
        response = perform_request(method, path, payload)

        track_last_response(method, path, response)
        log_debug(method, path, response)

        return response if (200..299).cover?(response.status)

        if retryable_status?(response.status) && attempts < DEFAULT_MAX_RETRIES
          sleep retry_delay(attempts, response)
          next
        end

        log_error(method, path, response)
        return response
      rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
        if attempts < DEFAULT_MAX_RETRIES
          sleep retry_delay(attempts, nil)
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
      when :delete
        connection.delete(path, payload)
      else
        raise ArgumentError, "Unsupported HTTP method: #{method}"
      end
    end

    def retryable_status?(status)
      RETRY_STATUSES.include?(status) || RETRY_RANGE.cover?(status)
    end

    def retry_delay(attempt, response)
      if response&.status.to_i == 429
        retry_after = response.headers['retry-after'].to_s
        if retry_after.match?(/\A\d+\z/)
          return retry_after.to_i
        end

        return 2.0 + rand * 0.5
      end

      0.5 * (2**(attempt - 1)) + (rand * 0.2)
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

    def track_last_response(method, path, response)
      @last_http_method = method.to_s.upcase
      @last_http_path = path
      @last_http_status = response&.status
    end

    def log_debug(method, path, response)
      return unless ENV['INSALES_HTTP_DEBUG'].to_s == '1'

      status = response&.status
      Rails.logger.info("[InSales] #{method.to_s.upcase} #{path} -> #{status}")
      if status.to_i >= 400
        Rails.logger.info("[InSales] Error body: #{response&.body.to_s.byteslice(0, MAX_ERROR_BODY_BYTES)}")
      end
    end

    public

    def last_http_status
      @last_http_status
    end

    def last_http_endpoint
      @last_http_path
    end
  end
end
