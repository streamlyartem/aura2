# frozen_string_literal: true

module Insales
  class CollectionsCache
    CACHE_KEY = 'insales:collections:all'.freeze
    DEFAULT_TTL = 15.minutes

    def initialize(client = Insales::InsalesClient.new)
      @client = client
    end

    def fetch
      Rails.cache.fetch(CACHE_KEY, expires_in: ttl) do
        fetch_from_api
      end
    end

    def invalidate
      Rails.cache.delete(CACHE_KEY)
    end

    private

    attr_reader :client

    def fetch_from_api
      response = client.collections_all
      return parse_collections(response&.body) if response_success?(response)

      Rails.logger.warn("[InSales][Collections] Fetch failed status=#{response&.status}")
      []
    rescue StandardError => e
      Rails.logger.warn("[InSales][Collections] Fetch failed: #{e.class} #{e.message}")
      []
    end

    def parse_collections(body)
      return body if body.is_a?(Array)
      return body['collections'] if body.is_a?(Hash) && body['collections'].is_a?(Array)
      return [body['collection']] if body.is_a?(Hash) && body['collection'].is_a?(Hash)
      return [body] if body.is_a?(Hash)

      []
    end

    def response_success?(response)
      response && (200..299).cover?(response.status)
    end

    def ttl
      DEFAULT_TTL
    end
  end
end
