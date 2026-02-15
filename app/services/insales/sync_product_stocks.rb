# frozen_string_literal: true

module Insales
  class SyncProductStocks
    Result = Struct.new(
      :processed,
      :created,
      :updated,
      :errors,
      :variant_updates,
      :images_uploaded,
      :images_skipped,
      :images_errors,
      :videos_uploaded,
      :videos_skipped,
      :verify_failures,
      :last_http_status,
      :last_http_endpoint,
      :last_error_message,
      keyword_init: true
    )

    def initialize(client = Insales::InsalesClient.new)
      @client = client
    end

    def call(store_name: 'Тест')
      result = Result.new(
        processed: 0,
        created: 0,
        updated: 0,
        errors: 0,
        variant_updates: 0,
        images_uploaded: 0,
        images_skipped: 0,
        images_errors: 0,
        videos_uploaded: 0,
        videos_skipped: 0,
        verify_failures: 0,
        last_error_message: nil
      )

      Rails.logger.info("[InSalesSync] Start sync for store '#{store_name}'")
      stock_by_product = ProductStock.where(store_name: store_name).group(:product_id).sum(:stock)
      product_ids = stock_by_product.keys
      Rails.logger.info("[InSalesSync] Products in stock: #{product_ids.size}")

      variants = []

      Product.where(id: product_ids).find_each do |product|

        result.processed += 1
        quantity = stock_by_product[product.id].to_f

        export_result = Insales::ExportProducts.call(product_id: product.id, dry_run: false)
        result.created += export_result.created
        result.updated += export_result.updated
        result.errors += export_result.errors

        mapping = InsalesProductMapping.find_by(aura_product_id: product.id)
        unless mapping
          result.errors += 1
          next
        end

        images_result = Insales::ExportImages.call(product_id: product.id, dry_run: false)
        result.images_uploaded += images_result.uploaded
        result.images_skipped += images_result.skipped
        result.images_errors += images_result.errors
        result.videos_skipped += 0

        variant_id = mapping.insales_variant_id || fetch_variant_id(mapping.insales_product_id)
        if variant_id
          mapping.update!(insales_variant_id: variant_id) if mapping.insales_variant_id != variant_id
          variants << { id: variant_id, quantity: quantity }
        else
          result.errors += 1
          Rails.logger.warn("[InSalesSync] Missing variant for product #{product.id}")
        end

        verify_result = Insales::VerifyProduct.new(client).call(
          product: product,
          insales_product_id: mapping.insales_product_id,
          insales_variant_id: mapping.insales_variant_id,
          expected_category_id: InsalesSetting.first&.category_id || ENV['INSALES_CATEGORY_ID'],
          expected_collection_id: InsalesSetting.first&.default_collection_id
        )

        unless verify_result.ok
          result.errors += 1
          result.verify_failures += 1
          result.last_error_message = verify_result.message
          Rails.logger.warn("[InSalesSync] Verify failed for product #{product.id}: #{verify_result.message}")
        end

        result.last_http_status = client.last_http_status
        result.last_http_endpoint = client.last_http_endpoint
      rescue StandardError => e
        result.errors += 1
        result.last_error_message = "#{e.class}: #{e.message}"
        Rails.logger.error("[InSalesSync] Error for product #{product&.id}: #{e.class} - #{e.message}")
      end

      result.variant_updates = update_variants_bulk(variants)
      Rails.logger.info("[InSalesSync] Done: processed=#{result.processed} created=#{result.created} updated=#{result.updated} errors=#{result.errors} variants_updated=#{result.variant_updates}")
      result
    end

    private

    attr_reader :client

    def fetch_variant_id(insales_product_id)
      response = client.get("/admin/products/#{insales_product_id}.json")
      return nil unless response_success?(response)

      extract_variant_id(response.body)
    end

    def extract_variant_id(body)
      return nil unless body.is_a?(Hash)

      variants = body['variants'] || body.dig('product', 'variants')
      variants&.first&.[]('id')
    end

    def update_variants_bulk(variants)
      updated = 0
      variants.each_slice(100) do |slice|
        response = client.put('/admin/products/variants_group_update.json', { variants: slice })
        if response_success?(response)
          updated += slice.size
        else
          Rails.logger.warn("[InSalesSync] Bulk update failed status=#{response&.status}")
        end
      end
      updated
    end

    def response_success?(response)
      response && (200..299).cover?(response.status)
    end
  end
end
