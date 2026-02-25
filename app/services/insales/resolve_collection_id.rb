# frozen_string_literal: true

module Insales
  class ResolveCollectionId
    CACHE_KEY = 'insales:collections:index'.freeze
    DEFAULT_CACHE_TTL = 10.minutes

    def initialize(client = Insales::InsalesClient.new)
      @client = client
      @index_builder = Insales::CollectionsIndex.new
    end

    def resolve(full_path, autocreate: nil)
      normalized = index_builder.normalize_path(full_path)
      return nil if normalized.blank?

      autocreate = autocreate_enabled? if autocreate.nil?

      manual_mapping = mapping_for_path(normalized)
      return handle_success(normalized, manual_mapping) if manual_mapping

      index = load_index
      collection = index.by_full_path[normalized]
      return handle_success(normalized, collection) if collection.present?

      return handle_failure(normalized, 'Collection path not found') unless autocreate

      leaf = create_missing_collections(normalized, index)
      return handle_failure(normalized, 'Failed to create collection path') if leaf.blank?

      update_cache(index)
      handle_success(normalized, leaf)
    end

    private

    attr_reader :client, :index_builder

    def load_index
      Rails.cache.fetch(CACHE_KEY, expires_in: cache_ttl) do
        collections = fetch_collections
        index_builder.build_index(collections)
      end
    end

    def update_cache(index)
      Rails.cache.write(CACHE_KEY, index, expires_in: cache_ttl)
    end

    def fetch_collections
      response = client.get_collections
      return parse_collections(response&.body) if response_success?(response)

      Rails.logger.warn("[InSales][Collections] Fetch failed status=#{response&.status}")
      []
    rescue StandardError => e
      Rails.logger.warn("[InSales][Collections] Fetch failed: #{e.class} #{e.message}")
      []
    end

    def create_missing_collections(normalized, index)
      parts = normalized.split('/').map { |segment| index_builder.normalize_segment(segment) }.reject(&:blank?)
      return nil if parts.empty?

      parent_id = nil
      parts.each do |segment|
        candidates = index.children_by_parent_id[parent_id] || []
        existing = candidates.find { |collection| index_builder.normalize_segment(collection['title']).casecmp(segment).zero? }
        if existing
          parent_id = existing['id']
          next
        end

        response = client.create_collection(title: segment, parent_id: parent_id)
        unless response_success?(response)
          Rails.logger.warn("[InSales][Collections] Create failed title=#{segment} parent_id=#{parent_id} status=#{response&.status}")
          return nil
        end

        created = extract_collection(response.body)
        return nil unless created

        index.by_id[created['id']] = created
        index.children_by_parent_id[parent_id] ||= []
        index.children_by_parent_id[parent_id] << created
        index.by_full_path[index_builder.normalize_path(build_path_from(created, index.by_id))] = created
        parent_id = created['id']
      end

      index.by_id[parent_id]
    end

    def build_path_from(collection, by_id)
      names = []
      current = collection
      while current
        names << index_builder.normalize_segment(current['title'])
        parent_id = current['parent_id']
        current = parent_id ? by_id[parent_id] : nil
      end
      names.reverse.join('/')
    end

    def handle_success(normalized, collection)
      upsert_status(
        normalized,
        sync_status: 'ok',
        insales_collection_id: collection['id'],
        insales_collection_title: collection['title'],
        insales_parent_collection_id: collection['parent_id'],
        last_error: nil
      )
      collection['id']
    end

    def handle_failure(normalized, error)
      upsert_status(normalized, sync_status: 'failed', last_error: error)
      nil
    end

    def upsert_status(path, attrs)
      payload = {
        aura_path: path,
        synced_at: Time.current
      }.merge(attrs)

      InsalesCategoryStatus.upsert(payload, unique_by: :index_insales_category_statuses_on_aura_path)
    rescue StandardError => e
      Rails.logger.warn("[InSales][Collections] Status upsert failed path=#{path} error=#{e.class} #{e.message}")
    end

    def mapping_for_path(normalized)
      mapping = InsalesCategoryMapping.where(is_active: true, aura_key_type: 'path').find do |candidate|
        index_builder.normalize_path(candidate.aura_key).casecmp(normalized).zero?
      end
      return nil unless mapping

      {
        'id' => mapping.insales_category_id,
        'title' => mapping.insales_collection_title,
        'parent_id' => nil
      }
    end

    def extract_collection(body)
      return body if body.is_a?(Hash) && body['id']
      return body['collection'] if body.is_a?(Hash) && body['collection'].is_a?(Hash)

      nil
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

    def autocreate_enabled?
      ENV.fetch('INS_SALES_AUTOCREATE_COLLECTIONS', 'false') == 'true'
    end

    def cache_ttl
      ttl = ENV.fetch('INS_SALES_COLLECTIONS_CACHE_TTL', nil)
      return DEFAULT_CACHE_TTL if ttl.blank?

      ttl.to_i.seconds
    end
  end
end
