# frozen_string_literal: true

module Moysklad
  module WebhookHandlers
    class ProductUpdateHandler < BaseHandler
      def handle
        return unless href

        data = fetch_entity_data
        return unless data

      ms_product = ::Moysklad::Product.new(data)
      if ms_product.sku.blank?
        Rails.logger.info "[Moysklad Webhook] Skip product without article ms_id=#{ms_product.id}"
        return
      end

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
          structure: ms_product.structure,
          code: ms_product.code,
          barcodes: ms_product.barcodes,
          purchase_price: ms_product.purchase_price.to_f,
          retail_price: ms_product.retail_price.to_f,
          small_wholesale_price: ms_product.small_wholesale_price.to_f,
          large_wholesale_price: ms_product.large_wholesale_price.to_f,
          five_hundred_plus_wholesale_price: ms_product.five_hundred_plus_wholesale_price.to_f,
          min_price: ms_product.min_price.to_f
        )
        sync_stock_with_weight(product, ms_product.weight)

        Rails.logger.info "[Moysklad Webhook] Product #{product.id} updated from Moysklad"
      end

      private

      def sync_stock_with_weight(product, weight)
        stock_value = weight.to_f
        stock = ::ProductStock.find_or_initialize_by(
          product_id: product.id,
          store_name: ::MoyskladClient::TEST_STORE_NAME
        )

        return if stock.persisted? && stock.stock.to_f == stock_value

        stock.assign_attributes(
          stock: stock_value,
          synced_at: Time.current
        )
        stock.free_stock = stock_value if stock.new_record? && stock.free_stock.nil?
        stock.save!
      end
    end
  end
end
