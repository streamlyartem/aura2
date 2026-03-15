# frozen_string_literal: true

module Insales
  module ApiV1
    class UpsertItemContract
      REQUIRED_KEYS = %w[external_id sku name updated_at currency price_minor stock_qty].freeze

      def validate(item)
        errors = []
        data = item.to_h.deep_stringify_keys

        REQUIRED_KEYS.each do |key|
          errors << { field: key, reason: 'is required' } if data[key].blank?
        end

        validate_number(errors, data, 'price_minor', min: 0)
        validate_number(errors, data, 'stock_qty')

        unless data['updated_at'].blank?
          Time.iso8601(data['updated_at'])
        end

        errors << { field: 'currency', reason: 'must be RUB' } if data['currency'].present? && data['currency'] != 'RUB'

        { valid: errors.empty?, errors: errors, item: data }
      rescue ArgumentError
        { valid: false, errors: [{ field: 'updated_at', reason: 'must be ISO8601' }], item: data }
      end

      private

      def validate_number(errors, data, key, min: nil)
        value = Integer(data[key])
        errors << { field: key, reason: "must be >= #{min}" } if !min.nil? && value < min
      rescue StandardError
        errors << { field: key, reason: 'must be integer' }
      end
    end
  end
end
