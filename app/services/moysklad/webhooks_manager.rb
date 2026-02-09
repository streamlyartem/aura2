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

      existing = list
      desired = ACTIONS.map { |action| desired_payload(webhook_url, action) }

      desired.each do |payload|
        if webhook_exists?(existing, payload)
          result.skipped += 1
          Rails.logger.info("[MoySklad] Skip #{payload['action']} #{payload['entityType']} #{payload['url']}")
          next
        end

        response = request(:post, payload)
        if response.is_a?(Net::HTTPSuccess)
          result.created += 1
          Rails.logger.info("[MoySklad] Created #{payload['action']} #{payload['entityType']} #{payload['url']}")
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
        next unless row['url'] == webhook_url

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
      ENV.fetch('MOYSKLAD_WEBHOOK_URL', STAGING_URL)
    end

    def token
      ENV['MOYSKLAD_TOKEN']
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

    def request(method, payload = nil, id = nil)
      return missing_token unless token.to_s.strip.present?

      uri = id ? URI("#{BASE_URL}/#{id}") : URI(BASE_URL)
      request = build_request(method, uri)

      if payload
        request['Content-Type'] = 'application/json'
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
      request['Content-Type'] = 'application/json;charset=utf-8'
      request
    end

    def missing_token
      Rails.logger.error('[MoySklad] Missing MOYSKLAD_TOKEN')
      Net::HTTPResponse.new('1.1', '401', 'Missing token')
    end

    def short_body(body)
      body.to_s.byteslice(0, 300)
    end
  end
end
