# frozen_string_literal: true

module Insales
  class SyncStore
    Result = Struct.new(:processed, :created, :updated, :errors, :variant_updates, keyword_init: true)

    def initialize(client = Insales::InsalesClient.new)
      @client = client
    end

    def call(store_name:, collection_id:, update_product_fields:, sync_images:)
      result = Result.new(processed: 0, created: 0, updated: 0, errors: 0, variant_updates: 0)

      stock_by_product = ProductStock.where(store_name: store_name).group(:product_id).sum(:stock)
      product_ids = stock_by_product.keys
      return result if product_ids.empty?

      Product.where(id: product_ids).find_each do |product|
        result.processed += 1
        quantity = stock_by_product[product.id].to_f

        mapping = InsalesProductMapping.find_by(aura_product_id: product.id)
        if mapping.nil?
          Insales::ExportProducts.call(product_id: product.id, collection_id: collection_id, dry_run: false)
          mapping = InsalesProductMapping.find_by(aura_product_id: product.id)
          result.created += 1 if mapping
        elsif update_product_fields
          Insales::ExportProducts.call(product_id: product.id, collection_id: collection_id, dry_run: false)
          result.updated += 1
        end

        mapping = InsalesProductMapping.find_by(aura_product_id: product.id)
        unless mapping
          result.errors += 1
          next
        end

        variant_id = mapping.insales_variant_id || fetch_variant_id(mapping.insales_product_id)
        if variant_id
          mapping.update!(insales_variant_id: variant_id) if mapping.insales_variant_id != variant_id
          variants_queue << { id: variant_id, quantity: quantity }
        else
          result.errors += 1
        end

        Insales::ExportImages.call(product_id: product.id, dry_run: false) if sync_images
      rescue StandardError => e
        result.errors += 1
        Rails.logger.error("[InSales] SyncStore failed for #{product.id}: #{e.class} - #{e.message}")
      end

      result.variant_updates = update_variants_bulk(variants_queue)
      result
    end

    private

    attr_reader :client

    def variants_queue
      @variants_queue ||= []
    end

    def update_variants_bulk(variants)
      updated = 0
      variants.each_slice(100) do |slice|
        response = client.put('/admin/products/variants_group_update.json', { variants: slice })
        if response_success?(response)
          updated += slice.size
        else
          Rails.logger.warn("[InSales] Bulk variant update failed status=#{response&.status}")
        end
      end
      updated
    end

    def fetch_variant_id(insales_product_id)
      response = client.get("/admin/products/#{insales_product_id}.json")
      return nil unless response_success?(response)

      body = response.body
      variants = body['variants'] || body.dig('product', 'variants')
      variants&.first&.[]('id')
    end

    def response_success?(response)
      response && (200..299).cover?(response.status)
    end
  end
end
