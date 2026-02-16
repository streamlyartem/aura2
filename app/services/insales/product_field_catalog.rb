# frozen_string_literal: true

module Insales
  class ProductFieldCatalog
    FieldDefinition = Struct.new(:key, :title, :extractor, keyword_init: true)

    FIELD_DEFINITIONS = [
      FieldDefinition.new(
        key: :aura_product_type,
        title: 'AURA: Тип товара',
        extractor: ->(product) { product.path_name.to_s.split('/').first }
      ),
      FieldDefinition.new(
        key: :aura_tone,
        title: 'AURA: Тон',
        extractor: ->(product) { product.tone }
      ),
      FieldDefinition.new(
        key: :aura_color,
        title: 'AURA: Цвет',
        extractor: ->(product) { product.color }
      ),
      FieldDefinition.new(
        key: :aura_length_cm,
        title: 'AURA: Длина (см)',
        extractor: ->(product) { product.length }
      ),
      FieldDefinition.new(
        key: :aura_weight_g,
        title: 'AURA: Вес (г)',
        extractor: ->(product) { product.weight }
      ),
      FieldDefinition.new(
        key: :aura_ombre,
        title: 'AURA: Омбре',
        extractor: ->(product) { product.ombre ? 'Да' : 'Нет' }
      ),
      FieldDefinition.new(
        key: :aura_batch_number,
        title: 'AURA: Партия',
        extractor: ->(product) { product.batch_number }
      ),
      FieldDefinition.new(
        key: :aura_price_retail,
        title: 'AURA: Цена розница',
        extractor: ->(product) { product.retail_price }
      ),
      FieldDefinition.new(
        key: :aura_price_small_wholesale,
        title: 'AURA: Цена мелкий опт',
        extractor: ->(product) { product.small_wholesale_price }
      ),
      FieldDefinition.new(
        key: :aura_price_large_wholesale,
        title: 'AURA: Цена крупный опт',
        extractor: ->(product) { product.large_wholesale_price }
      ),
      FieldDefinition.new(
        key: :aura_pricing_policy,
        title: 'AURA: Политика цен',
        extractor: lambda { |product|
          next unless product.path_name.to_s.split('/').first.to_s.casecmp('Срезы').zero?

          '0-499г: розница; 500-999г: мелкий опт; >=1000г: крупный опт'
        }
      )
    ].freeze

    def initialize(client)
      @client = client
      @field_ids_by_key = nil
    end

    def product_field_values_attributes(product)
      field_ids = ensure_field_ids!

      FIELD_DEFINITIONS.each_with_object([]) do |definition, result|
        value = normalize_value(definition.extractor.call(product))
        next if value.blank?

        field_id = field_ids[definition.key]
        next if field_id.blank?

        result << {
          product_field_id: field_id,
          value: value
        }
      end
    rescue StandardError => e
      raise if Rails.env.test?

      Rails.logger.warn("[InSales] Product fields mapping failed for product=#{product.id}: #{e.class} #{e.message}")
      []
    end

    private

    attr_reader :client

    def ensure_field_ids!
      return @field_ids_by_key if @field_ids_by_key.present?

      existing_by_title = fetch_existing_fields
      missing = FIELD_DEFINITIONS.select { |field| existing_by_title[field.title].blank? }

      missing.each do |field|
        response = client.post('/admin/product_fields.json', { product_field: { title: field.title } })
        next unless response_success?(response)

        created_id = extract_field_id(response.body)
        existing_by_title[field.title] = created_id if created_id.present?
      end

      @field_ids_by_key = FIELD_DEFINITIONS.to_h do |field|
        [field.key, existing_by_title[field.title]]
      end
    end

    def fetch_existing_fields
      response = client.get('/admin/product_fields.json')
      return {} unless response_success?(response)

      parse_fields(response.body).each_with_object({}) do |field, map|
        title = field['title'].to_s
        next if title.blank?

        map[title] = field['id']
      end
    end

    def parse_fields(body)
      return body if body.is_a?(Array)
      return body['product_fields'] if body.is_a?(Hash) && body['product_fields'].is_a?(Array)
      return [body['product_field']] if body.is_a?(Hash) && body['product_field'].is_a?(Hash)
      return [body] if body.is_a?(Hash)

      []
    end

    def extract_field_id(body)
      return nil unless body.is_a?(Hash)

      body['id'] || body.dig('product_field', 'id')
    end

    def response_success?(response)
      response && (200..299).cover?(response.status)
    end

    def self.format_number(value)
      return nil if value.nil?

      number = value.to_f
      return number.to_i.to_s if (number % 1).zero?

      format('%.2f', number)
    end

    def format_number(value)
      self.class.format_number(value)
    end

    def normalize_value(value)
      return nil if value.nil?
      return 'Да' if value == true
      return 'Нет' if value == false

      return format_number(value) if value.is_a?(Numeric)

      value.to_s.strip
    end
  end
end
