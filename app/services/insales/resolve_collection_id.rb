# frozen_string_literal: true

module Insales
  class ResolveCollectionId
    def initialize(client = Insales::InsalesClient.new)
      @client = client
      @index_builder = Insales::CollectionsIndex.new
      @cache = Insales::CollectionsCache.new(client)
    end

    def resolve(full_path, autocreate: nil)
      normalized = index_builder.normalize_path(full_path)
      return nil if normalized.blank?

      autocreate = autocreate_enabled? if autocreate.nil?

      manual_mapping = mapping_for_path(normalized)
      return handle_success(normalized, manual_mapping) if manual_mapping

      collections = cache.fetch
      collection = resolve_by_tree(collections, normalized, autocreate: autocreate)
      return handle_success(normalized, collection) if collection.present?

      handle_failure(normalized, 'Collection path not found')
    end

    private

    attr_reader :client, :index_builder, :cache

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

    def resolve_by_tree(collections, normalized, autocreate:)
      parts = normalized.split('/').map { |segment| index_builder.normalize_segment(segment) }.reject(&:blank?)
      return nil if parts.empty?

      children_by_parent_id = collections.group_by { |collection| collection['parent_id'] }
      root = root_collection(children_by_parent_id)
      parent_id = root ? root['id'] : nil

      parts.each do |segment|
        candidates = children_by_parent_id[parent_id] || []
        existing = candidates.find { |collection| index_builder.normalize_segment(collection['title']).casecmp(segment).zero? }
        if existing
          parent_id = existing['id']
          next
        end

        return nil unless autocreate

        response = client.collection_create(title: segment, parent_id: parent_id)
        unless response_success?(response)
          Rails.logger.warn("[InSales][Collections] Create failed title=#{segment} parent_id=#{parent_id} status=#{response&.status}")
          return nil
        end

        created = extract_collection(response.body)
        return nil unless created

        collections << created
        children_by_parent_id[parent_id] ||= []
        children_by_parent_id[parent_id] << created
        parent_id = created['id']
      end

      collections.find { |collection| collection['id'] == parent_id }
    ensure
      cache.invalidate if autocreate
    end

    def root_collection(children_by_parent_id)
      roots = children_by_parent_id[nil] || []
      return nil if roots.empty?
      return roots.first if roots.length == 1

      roots.find { |collection| index_builder.normalize_segment(collection['title']).casecmp('Каталог').zero? }
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

    def response_success?(response)
      response && (200..299).cover?(response.status)
    end

    def autocreate_enabled?
      ENV.fetch('INS_SALES_AUTOCREATE_COLLECTIONS', 'false') == 'true'
    end
  end
end
