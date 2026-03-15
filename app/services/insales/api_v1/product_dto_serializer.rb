# frozen_string_literal: true

module Insales
  module ApiV1
    class ProductDtoSerializer
      SCHEMA_VERSION = '1.0'.freeze

      def initialize(product, stock_scope: nil)
        @product = product
        @stock_scope = stock_scope
      end

      def as_json(*)
        {
          schema_version: SCHEMA_VERSION,
          external_id: product.id,
          sku: product.sku,
          name: product.name,
          type: product.path_name.to_s.split('/').first,
          price_minor: to_minor(product.retail_price),
          currency: 'RUB',
          stock_qty: stock_qty,
          weight_grams: decimal_to_number(product.weight),
          length_cm: decimal_to_number(product.length),
          tone: product.tone,
          structure: product.structure,
          color: product.color,
          description: nil,
          media: media,
          attributes: {
            insales_collection_key: product.path_name,
            aura_updated_at: product.updated_at&.iso8601
          },
          updated_at: product.updated_at&.iso8601
        }
      end

      private

      attr_reader :product, :stock_scope

      def stock_qty
        scope = stock_scope || ProductStock.where(product_id: product.id)
        scope.sum(:stock).to_i
      end

      def media
        product.images.filter_map do |image|
          next unless image.file.attached?

          {
            url: image.file.url,
            type: image.video? ? 'video' : 'image',
            checksum: image.file.blob&.checksum,
            position: image.id
          }
        end
      end

      def to_minor(amount)
        return 0 if amount.blank?

        (amount.to_d * 100).round(0).to_i
      end

      def decimal_to_number(value)
        return nil if value.blank?

        value.to_d.to_f
      end
    end
  end
end
