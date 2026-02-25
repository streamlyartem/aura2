# frozen_string_literal: true

module Insales
  class CategoryResolver
    def initialize(client = Insales::InsalesClient.new)
      @mapping_resolver = Insales::CategoryMappingResolver.new
      @tree_resolver = Insales::CategoryTreeResolver.new(client)
    end

    def category_id_for(product)
      mapping_id = mapping_resolver.category_id_for(product)
      return mapping_id if mapping_id.present?

      return nil unless use_tree_lookup?(product)

      tree_resolver.category_id_for_path(product.path_name)
    end

    private

    attr_reader :mapping_resolver, :tree_resolver

    def use_tree_lookup?(product)
      product_type = product.path_name.to_s.split('/').first.to_s
      product_type.casecmp('Срезы').zero?
    end
  end
end
