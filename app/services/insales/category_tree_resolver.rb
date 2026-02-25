# frozen_string_literal: true

module Insales
  class CategoryTreeResolver
    CACHE_KEY = 'insales:collections:index'
    CACHE_TTL = 10.minutes

    def initialize(client = Insales::InsalesClient.new)
      @client = client
    end

    def category_id_for_path(path_name)
      parts = path_parts(path_name)
      return nil if parts.empty?

      index = category_index
      return nil if index.empty?

      parent_id = nil
      parts.each do |name|
        candidate = (index[parent_id] || []).find do |collection|
          collection['title'].to_s.casecmp(name).zero?
        end
        return nil unless candidate

        parent_id = candidate['id']
      end

      parent_id
    end

    def category_paths
      index = category_index
      return [] if index.empty?

      collections = index.values.flatten
      by_id = collections.index_by { |collection| collection['id'] }

      collections.map do |collection|
        {
          id: collection['id'],
          path: build_path(collection, by_id)
        }
      end
    end

    private

    attr_reader :client

    def category_index
      Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
        collections = fetch_collections
        collections.group_by { |collection| collection['parent_id'] }
      end
    end

    def fetch_collections
      response = client.get('/admin/collections.json')
      return [] unless response_success?(response)

      parse_collections(response.body)
    rescue StandardError => e
      Rails.logger.warn("[InSales][Collection] Fetch collections failed: #{e.class} #{e.message}")
      []
    end

    def build_path(collection, by_id)
      names = []
      current = collection
      while current
        names << current['title'].to_s
        parent_id = current['parent_id']
        current = parent_id ? by_id[parent_id] : nil
      end
      names.reverse
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

    def path_parts(path_name)
      path_name.to_s.split('/').map(&:strip).reject(&:blank?)
    end
  end
end
