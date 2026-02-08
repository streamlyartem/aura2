# frozen_string_literal: true

module Moysklad
  module WebhookHandlers
    # Base class for all webhook handlers
    class BaseHandler
      attr_reader :event, :client

      def initialize(event)
        @event = event
        @client = MoyskladClient.new(base_url: nil)
      end

      def handle
        raise NotImplementedError, "#{self.class} must implement #handle"
      end

      protected

      def entity_type
        @entity_type ||= event.dig('meta', 'type')
      end

      def action
        @action ||= event['action']
      end

      def href
        @href ||= event.dig('meta', 'href')
      end

      def fetch_entity_data(href_to_fetch = href)
        return nil unless href_to_fetch

        Rails.logger.debug { "[Moysklad Webhook] Fetching entity from: #{href_to_fetch}" }

        begin
          response = client.get_full(href_to_fetch)

          unless response.status == 200
            Rails.logger.warn "[Moysklad Webhook] Failed to fetch entity #{href_to_fetch}: #{response.status}"
            return nil
          end

          response.body
        rescue Moysklad::HttpClient::Error => e
          Rails.logger.warn "[Moysklad Webhook] Error fetching entity #{href_to_fetch}: #{e.message}"
          nil
        end
      end

      def extract_id_from_href(href_to_parse = href)
        return nil unless href_to_parse

        href_to_parse.split('/').last
      rescue StandardError => e
        Rails.logger.warn "[Moysklad Webhook] Failed to parse ID from href #{href_to_parse}: #{e.message}"
        nil
      end
    end
  end
end
