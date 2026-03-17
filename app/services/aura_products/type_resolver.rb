# frozen_string_literal: true

module AuraProducts
  class TypeResolver
    def initialize(types: nil)
      @types = types || AuraProductType.active.ordered.to_a
    end

    def resolve(product)
      return nil if product.blank?

      @types.find { |type| type.matches?(product) }
    end
  end
end
