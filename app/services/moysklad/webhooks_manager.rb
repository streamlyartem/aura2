# frozen_string_literal: true

require 'json'
require 'net/http'

module Moysklad
  class WebhooksManager
    Result = Struct.new(:created, :skipped, :deleted, :errors, keyword_init: true)

    ACTIONS = %w[CREATE UPDATE DELETE].freeze
    ENTITY_TYPE = 'product'
    BASE_URL = 'https://api.moysklad.ru/api/remap/1.2/entity/webhook'
    STAGING_URL = 'https://staging-aura.tophair.tech/api/moysklad/webhooks'

    def list
      response = request(:get)
      return [] unless response.is_a?(Net::HTTPSuccess)

      body = JSON.parse(response.body) rescue {}
      body['rows'] || []
    end

    def ensure
      result = Result.new(created: 0, skipped: 0, deleted: 0, errors: 0)

      raise_missing_webhook_token! if webhook_token.to_s.strip.empty?

      existing = list
      desired = ACTIONS.map { |action| desired_payload(webhook_url, action) }

      desired.each do |payload|
        if webhook_exists?(existing, payload)
          result.skipped += 1
          Rails.logger.info("[MoySklad] Skip #{payload['action']} #{payload['entityType']} #{masked_url(payload['url'])}")
          next
        end

        delete_stale(existing, payload)

        response = request(:post, payload)
        if response.is_a?(Net::HTTPSuccess)
          result.created += 1
          Rails.logger.info("[MoySklad] Created #{payload['action']} #{payload['entityType']} #{masked_url(payload['url'])}")
        else
          result.errors += 1
          Rails.logger.error("[MoySklad] Create failed status=#{response.code} body=#{short_body(response.body)}")
        end
      end

      result
    end

    def delete_all_for_url
      result = Result.new(created: 0, skipped: 0, deleted: 0, errors: 0)
      existing = list
      existing.each do |row|
        next unless same_base_url?(row['url'], webhook_url)

        response = request(:delete, nil, row['id'])
        if response.is_a?(Net::HTTPSuccess)
          result.deleted += 1
          Rails.logger.info("[MoySklad] Deleted webhook #{row['id']}")
        else
          result.errors += 1
          Rails.logger.error("[MoySklad] Delete failed status=#{response.code} body=#{short_body(response.body)}")
        end
      end

      result
    end

    private

    def webhook_url
      base_url = ENV['MOYSKLAD_WEBHOOK_URL'].presence || default_webhook_base_url
      Rails.logger.info("[MoySklad] Webhook token present=#{webhook_token.to_s.strip.present?}")
      append_token(base_url, webhook_token)
    end

    def token
      ENV['MOYSKLAD_API_TOKEN'].presence || ENV['MOYSKLAD_TOKEN']
    end

    def webhook_token
      ENV['MOYSKLAD_WEBHOOK_TOKEN']
    end

    def default_webhook_base_url
      host = ENV['APP_HOST'].presence ||
             ENV['RAILS_HOST'].presence ||
             Rails.application.routes.default_url_options[:host]
      return STAGING_URL if host.blank?

      "https://#{host}/api/moysklad/webhooks"
    end

    def append_token(base_url, token)
      uri = URI(base_url)
      params = URI.decode_www_form(uri.query.to_s)
      params.reject! { |(key, _)| key == 'token' }
      params << ['token', token.to_s]
      uri.query = URI.encode_www_form(params)
      uri.to_s
    end

    def desired_payload(url, action)
      {
        'url' => url,
        'action' => action,
        'entityType' => ENTITY_TYPE
      }
    end

    def webhook_exists?(existing, payload)
      existing.any? do |row|
        row['url'] == payload['url'] &&
          row['action'] == payload['action'] &&
          row['entityType'] == payload['entityType']
      end
    end

    def delete_stale(existing, payload)
      existing.each do |row|
        next unless row['action'] == payload['action']
        next unless row['entityType'] == payload['entityType']
        next unless same_base_url?(row['url'], payload['url'])
        next if row['url'] == payload['url']

        response = request(:delete, nil, row['id'])
        if response.is_a?(Net::HTTPSuccess)
          Rails.logger.info("[MoySklad] Deleted stale webhook #{row['id']}")
        else
          Rails.logger.error("[MoySklad] Delete failed status=#{response.code} body=#{short_body(response.body)}")
        end
      end
    end

    def same_base_url?(left, right)
      left_uri = URI(left.to_s)
      right_uri = URI(right.to_s)
      left_uri.scheme == right_uri.scheme &&
        left_uri.host == right_uri.host &&
        left_uri.path == right_uri.path
    end

    def request(method, payload = nil, id = nil)
      return missing_token unless token.to_s.strip.present?

      uri = id ? URI("#{BASE_URL}/#{id}") : URI(BASE_URL)
      request = build_request(method, uri)

      if payload
        request['Content-Type'] = 'application/json;charset=utf-8'
        request.body = JSON.generate(payload)
      end

      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request(request)
      end
    end

    def build_request(method, uri)
      request = case method
                when :get then Net::HTTP::Get.new(uri)
                when :post then Net::HTTP::Post.new(uri)
                when :delete then Net::HTTP::Delete.new(uri)
                else raise ArgumentError, "Unsupported method: #{method}"
                end
      request['Authorization'] = "Bearer #{token}"
      request['Accept'] = 'application/json;charset=utf-8'
      request
    end

    def missing_token
      Rails.logger.error('[MoySklad] Missing MOYSKLAD_API_TOKEN')
      Net::HTTPResponse.new('1.1', '401', 'Missing token')
    end

    def raise_missing_webhook_token!
      Rails.logger.error('[MoySklad] Missing MOYSKLAD_WEBHOOK_TOKEN')
      raise ArgumentError, 'Missing MOYSKLAD_WEBHOOK_TOKEN'
    end

    def masked_url(url)
      token = webhook_token.to_s
      return url if token.empty?

      masked = token.length <= 4 ? '****' : "****#{token[-4, 4]}"
      url.to_s.gsub(/token=[^&]+/, "token=#{masked}")
    end

    def short_body(body)
      body.to_s.byteslice(0, 300)
    end
  end
end
