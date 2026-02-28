# frozen_string_literal: true

require 'json'
require 'net/http'

module Moysklad
  module Webhooks
    class Registrar
      Result = Struct.new(:created, :skipped, :errors, keyword_init: true)

      ACTIONS = %w[CREATE UPDATE DELETE].freeze
      ENTITY_TYPE = 'product'
      ENDPOINT = 'https://online.moysklad.ru/api/remap/1.2/entity/webhook'

      def ensure!
        result = Result.new(created: 0, skipped: 0, errors: 0)

        token = ENV['MOYSKLAD_API_TOKEN'].presence || ENV['MOYSKLAD_TOKEN']
        url = ENV['MOYSKLAD_WEBHOOK_URL']

        if token.to_s.strip.empty? || url.to_s.strip.empty?
          Rails.logger.error('[MoySkladWebhooks] Missing MOYSKLAD_API_TOKEN or MOYSKLAD_WEBHOOK_URL')
          result.errors += 1
          return result
        end

        existing = fetch_existing(token)
        desired = ACTIONS.map { |action| desired_payload(url, action) }

        desired.each do |payload|
          if webhook_exists?(existing, payload)
            result.skipped += 1
            Rails.logger.info("[MoySkladWebhooks] Skip #{payload['action']} #{payload['entityType']} #{payload['url']}")
            next
          end

          response = post_webhook(token, payload)
          if response.is_a?(Net::HTTPSuccess)
            result.created += 1
            Rails.logger.info("[MoySkladWebhooks] Created #{payload['action']} #{payload['entityType']} #{payload['url']}")
          else
            result.errors += 1
            Rails.logger.error("[MoySkladWebhooks] Create failed status=#{response.code} body=#{short_body(response.body)}")
          end
        end

        result
      end

      private

      def desired_payload(url, action)
        {
          'url' => url,
          'action' => action,
          'entityType' => ENTITY_TYPE
        }
      end

      def fetch_existing(token)
        response = get_webhooks(token)
        return [] unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body) rescue {}
        body['rows'] || []
      end

      def webhook_exists?(existing, payload)
        existing.any? do |row|
          row['url'] == payload['url'] &&
            row['action'] == payload['action'] &&
            row['entityType'] == payload['entityType']
        end
      end

      def get_webhooks(token)
        uri = URI(ENDPOINT)
        request = Net::HTTP::Get.new(uri)
        request['Authorization'] = "Bearer #{token}"

        Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          ExternalHttpConfig.apply_net_http!(
            http,
            service: :moysklad,
            open_timeout: Moysklad::HttpClient::DEFAULT_OPEN_TIMEOUT,
            read_timeout: Moysklad::HttpClient::DEFAULT_TIMEOUT
          )
          http.request(request)
        end
      end

      def post_webhook(token, payload)
        uri = URI(ENDPOINT)
        request = Net::HTTP::Post.new(uri)
        request['Authorization'] = "Bearer #{token}"
        request['Content-Type'] = 'application/json'
        request.body = JSON.generate(payload)

        Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          ExternalHttpConfig.apply_net_http!(
            http,
            service: :moysklad,
            open_timeout: Moysklad::HttpClient::DEFAULT_OPEN_TIMEOUT,
            read_timeout: Moysklad::HttpClient::DEFAULT_TIMEOUT
          )
          http.request(request)
        end
      end

      def short_body(body)
        body.to_s.byteslice(0, 300)
      end
    end
  end
end
