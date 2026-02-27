# frozen_string_literal: true

module Insales
  class ProductPropertyCatalog
    PropertyDefinition = Struct.new(:title, :extractor, :digits_only, keyword_init: true)

    PROPERTY_DEFINITIONS = [
      PropertyDefinition.new(
        title: 'Тип товара',
        extractor: ->(product) { product.path_name.to_s.split('/').first }
      ),
      PropertyDefinition.new(
        title: 'Тон',
        extractor: ->(product) { product.tone }
      ),
      PropertyDefinition.new(
        title: 'Цвет',
        extractor: ->(product) { product.color }
      ),
      PropertyDefinition.new(
        title: 'Длина (см)',
        extractor: ->(product) { product.length },
        digits_only: true
      ),
      PropertyDefinition.new(
        title: 'Вес (г)',
        extractor: ->(product) { product.weight },
        digits_only: true
      ),
      PropertyDefinition.new(
        title: 'Омбре',
        extractor: ->(product) { product.ombre ? 'Да' : 'Нет' }
      ),
      PropertyDefinition.new(
        title: 'Структура',
        extractor: ->(product) { product.structure }
      )
    ].freeze

    def properties_attributes(product, existing_properties: [])
      existing_by_title = existing_properties.each_with_object({}) do |property, memo|
        next unless property.is_a?(Hash)

        title = property['title'].to_s.strip
        next if title.blank?

        memo[title] = property
      end

      PROPERTY_DEFINITIONS.each_with_object([]) do |definition, result|
        value = normalize_value(definition.extractor.call(product), digits_only: definition.digits_only)
        next if value.blank?

        # InSales product API expects a scalar `value` for properties_attributes.
        # `characteristics` in request payload is ignored for most property types.
        property = { title: definition.title, value: value }
        existing_id = existing_by_title.dig(definition.title, 'id')
        property[:id] = existing_id if existing_id.present?
        result << property
      end
    end

    private

    def normalize_value(value, digits_only:)
      return nil if value.nil?

      normalized = if digits_only
                     digits_value(value)
                   elsif value.is_a?(Numeric)
                     value.to_d.to_s('F')
                   else
                     value.to_s.strip
                   end

      normalized.presence
    end

    def digits_value(value)
      if value.is_a?(Numeric)
        return value.to_d.to_i.to_s
      end

      value.to_s.scan(/\d+/).join
    end
  end
end
