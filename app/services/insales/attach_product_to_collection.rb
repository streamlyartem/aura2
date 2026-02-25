# frozen_string_literal: true

module Insales
  class AttachProductToCollection
    def initialize(client = Insales::InsalesClient.new)
      @client = client
    end

    def ensure_attached(product_id:, collection_id:)
      collects = fetch_collects(product_id)
      return true if collects.any? { |collect| collect['collection_id'].to_s == collection_id.to_s }

      response = client.collect_create(product_id: product_id, collection_id: collection_id)
      return true if response_success?(response)
      return true if [409, 422].include?(response&.status)

      Rails.logger.warn("[InSales][Collect] create failed product_id=#{product_id} collection_id=#{collection_id} status=#{response&.status}")
      false
    end

    private

    attr_reader :client

    def fetch_collects(product_id)
      response = client.collects_by_product(product_id: product_id)
      return parse_collects(response&.body) if response_success?(response)

      []
    rescue StandardError => e
      Rails.logger.warn("[InSales][Collect] fetch failed product_id=#{product_id} error=#{e.class} #{e.message}")
      []
    end

    def parse_collects(body)
      return body if body.is_a?(Array)
      return body['collects'] if body.is_a?(Hash) && body['collects'].is_a?(Array)
      return [body['collect']] if body.is_a?(Hash) && body['collect'].is_a?(Hash)
      return [body] if body.is_a?(Hash)

      []
    end

    def response_success?(response)
      response && (200..299).cover?(response.status)
    end
  end
end
