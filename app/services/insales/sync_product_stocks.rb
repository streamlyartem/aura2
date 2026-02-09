# frozen_string_literal: true

module Insales
  class SyncProductStocks
    Result = Struct.new(:processed, :created, :updated, :errors, :variant_updates, keyword_init: true)

    def initialize(client = Insales::InsalesClient.new)
      @client = client
    end

    def call(store_name: 'Тест')
      result = Result.new(processed: 0, created: 0, updated: 0, errors: 0, variant_updates: 0)

      Rails.logger.info("[InSalesSync] Start sync for store '#{store_name}'")
      stock_by_product = ProductStock.where(store_name: store_name).group(:product_id).sum(:stock)
      product_ids = stock_by_product.keys
      Rails.logger.info("[InSalesSync] Products in stock: #{product_ids.size}")

      variants = []

      Product.where(id: product_ids).find_each do |product|

        result.processed += 1
        quantity = stock_by_product[product.id].to_f

        mapping = InsalesProductMapping.find_by(aura_product_id: product.id)
        unless mapping
          mapping = ensure_product_exists(product)
          if mapping
            result.created += 1
          else
            result.errors += 1
            next
          end
        else
          result.updated += 1
        end

        variant_id = mapping.insales_variant_id || fetch_variant_id(mapping.insales_product_id)
        if variant_id
          mapping.update!(insales_variant_id: variant_id) if mapping.insales_variant_id != variant_id
          variants << { id: variant_id, quantity: quantity }
        else
          result.errors += 1
          Rails.logger.warn("[InSalesSync] Missing variant for product #{product.id}")
        end
      rescue StandardError => e
        result.errors += 1
        Rails.logger.error("[InSalesSync] Error for product #{product&.id}: #{e.class} - #{e.message}")
      end

      result.variant_updates = update_variants_bulk(variants)
      Rails.logger.info("[InSalesSync] Done: processed=#{result.processed} created=#{result.created} updated=#{result.updated} errors=#{result.errors} variants_updated=#{result.variant_updates}")
      result
    end

    private

    attr_reader :client

    def ensure_product_exists(product)
      mapping = find_mapping_by_sku(product)
      return mapping if mapping

      Insales::ExportProducts.call(product_id: product.id, dry_run: false)
      InsalesProductMapping.find_by(aura_product_id: product.id)
    end

    def find_mapping_by_sku(product)
      sku = product.sku.presence || product.code
      return nil if sku.blank?

      response = client.get('/admin/products.json', { search: sku, page: 1, per_page: 1 })
      return nil unless response_success?(response)

      body = response.body
      product_data = body.is_a?(Array) ? body.first : body&.dig('products', 0)
      return nil unless product_data

      insales_id = product_data['id'] || product_data.dig('product', 'id')
      variant_id = extract_variant_id(product_data)
      return nil unless insales_id

      InsalesProductMapping.create!(
        aura_product_id: product.id,
        insales_product_id: insales_id,
        insales_variant_id: variant_id
      )
    rescue StandardError => e
      Rails.logger.warn("[InSalesSync] SKU lookup failed for #{product.id}: #{e.class} - #{e.message}")
      nil
    end

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
