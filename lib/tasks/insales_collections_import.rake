# frozen_string_literal: true

require 'json'

namespace :insales do
  desc 'Import InsalesCategoryMapping from collections JSON export'
  task import_collections: :environment do
    path = ENV.fetch('COLLECTIONS_JSON_PATH', nil)
    raise ArgumentError, 'COLLECTIONS_JSON_PATH is required' if path.blank?
    raise ArgumentError, "File not found: #{path}" unless File.exist?(path)

    data = JSON.parse(File.read(path))
    unless data.is_a?(Array)
      raise ArgumentError, 'collections JSON must be an array of collections'
    end

    by_id = data.index_by { |c| c['id'] }
    children = data.group_by { |c| c['parent_id'] }
    roots = children[nil] || []
    root = if roots.size == 1
             roots.first
           else
             roots.find { |c| c['title'].to_s.strip.casecmp('Каталог').zero? }
           end

    normalize = ->(s) { s.to_s.strip.gsub(/\s+/, ' ') }
    build_path = lambda do |collection|
      names = []
      current = collection
      while current
        names << normalize.call(current['title'])
        parent_id = current['parent_id']
        current = parent_id ? by_id[parent_id] : nil
      end
      names.reverse
    end

    leaf_collections = data.select do |collection|
      (children[collection['id']] || []).empty?
    end

    timestamp = Time.current
    payload = leaf_collections.map do |collection|
      path_parts = build_path.call(collection)
      path_parts.shift if root && path_parts.first.to_s.casecmp(normalize.call(root['title'])).zero?
      aura_key = path_parts.join('/')
      next if aura_key.blank?

      {
        aura_key_type: 'path',
        aura_key: aura_key,
        insales_category_id: collection['id'],
        insales_collection_title: collection['title'],
        comment: 'auto from collections.json',
        is_active: true,
        created_at: timestamp,
        updated_at: timestamp
      }
    end.compact

    if payload.empty?
      puts 'No mappings to import'
      next
    end

    result = InsalesCategoryMapping.upsert_all(
      payload,
      unique_by: :index_insales_category_mappings_on_aura_key_type_and_aura_key
    )

    puts "Imported/updated #{result.rows.length} mappings"
  end
end
