# frozen_string_literal: true

module Insales
  class CategoryMappingSync
    Result = Struct.new(:processed, :created, :updated, :errors, keyword_init: true)

    def initialize(client = Insales::InsalesClient.new)
      @tree_resolver = Insales::CategoryTreeResolver.new(client)
    end

    def call
      result = Result.new(processed: 0, created: 0, updated: 0, errors: 0)

      tree_resolver.category_paths.each do |entry|
        path = entry[:path]
        next if path.empty?
        next unless path.first.to_s.casecmp('Срезы').zero?

        mapping_attrs = build_mapping(path, entry[:id])
        next unless mapping_attrs

        result.processed += 1
        upsert_mapping(mapping_attrs, result)
      rescue StandardError
        result.errors += 1
      end

      result
    end

    private

    attr_reader :tree_resolver

    def build_mapping(path, category_id)
      product_type = path[0]
      tone = path[1]
      length = parse_length(path[2])

      {
        product_type: product_type,
        tone: tone,
        length: length,
        insales_category_id: category_id
      }.compact
    end

    def parse_length(value)
      return nil if value.blank?

      value.to_s.to_i
    end

    def upsert_mapping(attrs, result)
      mapping = InsalesCategoryMapping.find_or_initialize_by(
        product_type: attrs[:product_type],
        tone: attrs[:tone],
        length: attrs[:length],
        ombre: nil,
        structure: nil
      )
      if mapping.new_record?
        mapping.insales_category_id = attrs[:insales_category_id]
        mapping.save!
        result.created += 1
      else
        if mapping.insales_category_id != attrs[:insales_category_id]
          mapping.update!(insales_category_id: attrs[:insales_category_id])
          result.updated += 1
        end
      end
    end
  end
end
