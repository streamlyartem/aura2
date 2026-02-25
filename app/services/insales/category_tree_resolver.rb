# frozen_string_literal: true

module Insales
  class CategoryTreeResolver
    CACHE_KEY = 'insales:categories:index'
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
        candidate = (index[parent_id] || []).find do |category|
          category['title'].to_s.casecmp(name).zero?
        end
        return nil unless candidate

        parent_id = candidate['id']
      end

      parent_id
    end

    def category_paths
      index = category_index
      return [] if index.empty?

      categories = index.values.flatten
      by_id = categories.index_by { |category| category['id'] }

      categories.map do |category|
        {
          id: category['id'],
          path: build_path(category, by_id)
        }
      end
    end

    private

    attr_reader :client

    def category_index
      Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
        categories = fetch_categories
        categories.group_by { |category| category['parent_id'] }
      end
    end

    def fetch_categories
      response = client.get('/admin/categories.json')
      return [] unless response_success?(response)

      parse_categories(response.body)
    rescue StandardError => e
      Rails.logger.warn("[InSales][Category] Fetch categories failed: #{e.class} #{e.message}")
      []
    end

    def build_path(category, by_id)
      names = []
      current = category
      while current
        names << current['title'].to_s
        parent_id = current['parent_id']
        current = parent_id ? by_id[parent_id] : nil
      end
      names.reverse
    end

    def parse_categories(body)
      return body if body.is_a?(Array)
      return body['categories'] if body.is_a?(Hash) && body['categories'].is_a?(Array)
      return [body['category']] if body.is_a?(Hash) && body['category'].is_a?(Hash)
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
