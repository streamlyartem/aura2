# frozen_string_literal: true

module Moysklad
  module WebhookHandlers
    class ProductUpdateHandler < BaseHandler
      def handle
        return unless href

        data = fetch_entity_data
        return unless data

        ms_product = ::Moysklad::Product.new(data)

        product = ::Product.find_by(ms_id: ms_product.id)
        unless product
          Rails.logger.warn "[Moysklad Webhook] Product not found locally for ms_id #{ms_product.id}"
          return
        end

        product.update!(
          name: ms_product.name,
          sku: ms_product.sku,
          batch_number: ms_product.batch_number,
          path_name: ms_product.path_name,
          weight: ms_product.weight.to_f,
          length: ms_product.length,
          color: ms_product.color,
          tone: ms_product.tone,
          ombre: ms_product.ombre,
          code: ms_product.code,
          barcodes: ms_product.barcodes,
          purchase_price: ms_product.purchase_price.to_f,
          retail_price: ms_product.retail_price.to_f,
          small_wholesale_price: ms_product.small_wholesale_price.to_f,
          large_wholesale_price: ms_product.large_wholesale_price.to_f,
          five_hundred_plus_wholesale_price: ms_product.five_hundred_plus_wholesale_price.to_f,
          min_price: ms_product.min_price.to_f
        )

        Rails.logger.info "[Moysklad Webhook] Product #{product.id} updated from Moysklad"
      end
    end
  end
end
