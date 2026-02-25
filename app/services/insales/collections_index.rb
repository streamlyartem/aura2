# frozen_string_literal: true

module Insales
  class CollectionsIndex
    Index = Struct.new(:by_id, :children_by_parent_id, :by_full_path, keyword_init: true)

    def build_index(collections)
      by_id = collections.index_by { |collection| collection['id'] }
      children_by_parent_id = collections.group_by { |collection| collection['parent_id'] }
      by_full_path = {}

      collections.each do |collection|
        path = build_path(collection, by_id)
        next if path.empty?

        by_full_path[path.join('/')] = collection
      end

      Index.new(
        by_id: by_id,
        children_by_parent_id: children_by_parent_id,
        by_full_path: by_full_path
      )
    end

    def normalize_segment(segment)
      segment.to_s.strip.gsub(/\s+/, ' ')
    end

    def normalize_path(path)
      parts = path.to_s.split('/').map { |segment| normalize_segment(segment) }.reject(&:blank?)
      parts.join('/')
    end

    private

    def build_path(collection, by_id)
      names = []
      current = collection
      while current
        names << normalize_segment(current['title'])
        parent_id = current['parent_id']
        current = parent_id ? by_id[parent_id] : nil
      end
      names.reverse.reject(&:blank?)
    end
  end
end
