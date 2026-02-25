# frozen_string_literal: true

module Insales
  class CategoryMappingResolver
    def initialize(mappings = nil)
      @mappings = mappings || InsalesCategoryMapping.all.to_a
    end

    def category_id_for(product)
      product_type = extract_type(product)
      return nil if product_type.blank?

      matches = @mappings.select do |mapping|
        mapping.product_type.to_s.casecmp(product_type.to_s).zero? &&
          matches_optional?(mapping.tone, product.tone) &&
          matches_optional?(mapping.length, safe_length(product.length)) &&
          matches_optional_boolean?(mapping.ombre, product.ombre) &&
          matches_optional?(mapping.structure, product.structure)
      end

      best = matches.max_by(&:specificity_score)
      best&.insales_category_id
    end

    private

    def extract_type(product)
      product.path_name.to_s.split('/').first
    end

    def safe_length(value)
      return nil if value.nil?

      value.to_f.round
    end

    def matches_optional?(mapping_value, product_value)
      return true if mapping_value.blank?

      mapping_value.to_s.casecmp(product_value.to_s).zero?
    end

    def matches_optional_boolean?(mapping_value, product_value)
      return true if mapping_value.nil?

      mapping_value == product_value
    end
  end
end
