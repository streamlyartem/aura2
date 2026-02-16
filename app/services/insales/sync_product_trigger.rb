# frozen_string_literal: true

module Insales
  class SyncProductTrigger
    Result = Struct.new(:status, :action, :message, keyword_init: true)

    def initialize(client = Insales::InsalesClient.new)
      @client = client
    end

    def call(product_id:, reason: nil)
      product = Product.includes(:images).find_by(id: product_id)
      return Result.new(status: 'skipped', action: 'missing_product', message: 'Product not found') unless product

      in_stock = ProductStock.where(product_id: product.id).sum(:stock).to_f.positive?
      has_media = product.images.any? { |image| image.file.attached? }

      Rails.logger.info(
        "[InSalesSync][Trigger] product=#{product.id} reason=#{reason} in_stock=#{in_stock} has_media=#{has_media}"
      )

      if in_stock && has_media
        publish_or_update(product)
      else
        unpublish(product, in_stock: in_stock, has_media: has_media)
      end
    rescue StandardError => e
      Rails.logger.error("[InSalesSync][Trigger] product=#{product_id} failed: #{e.class} - #{e.message}")
      Result.new(status: 'error', action: 'failed', message: "#{e.class}: #{e.message}")
    end

    private

    attr_reader :client

    def publish_or_update(product)
      export_result = Insales::ExportProducts.call(product_id: product.id, dry_run: false)
      mapping = InsalesProductMapping.find_by(aura_product_id: product.id)

      unless mapping
        return Result.new(status: 'error', action: 'publish', message: 'InSales mapping missing after product export')
      end

      media_result = Insales::SyncProductMedia.new(client).call(
        product: product,
        insales_product_id: mapping.insales_product_id
      )

      ensure_visible(mapping.insales_product_id)

      if export_result.errors.to_i.positive? || media_result.status == 'error'
        message = media_result.last_error.presence || "Export errors=#{export_result.errors}"
        return Result.new(status: 'error', action: 'publish', message: message)
      end

      Result.new(status: 'success', action: 'publish', message: 'Published or updated')
    end

    def unpublish(product, in_stock:, has_media:)
      mapping = InsalesProductMapping.find_by(aura_product_id: product.id)
      return Result.new(status: 'skipped', action: 'unpublish', message: 'No InSales mapping') unless mapping

      payload = { product: { collection_ids: [], is_hidden: true } }
      response = client.put("/admin/products/#{mapping.insales_product_id}.json", payload)

      if hidden_field_rejected?(response)
        response = client.put(
          "/admin/products/#{mapping.insales_product_id}.json",
          { product: { collection_ids: [] } }
        )
      end

      unless success?(response)
        return Result.new(status: 'error', action: 'unpublish', message: "HTTP #{response&.status}")
      end

      reason = []
      reason << 'sold_out' unless in_stock
      reason << 'missing_media' unless has_media

      Result.new(status: 'success', action: 'unpublish', message: "Unpublished (#{reason.join('+')})")
    end

    def ensure_visible(insales_product_id)
      response = client.put("/admin/products/#{insales_product_id}.json", { product: { is_hidden: false } })
      return if success?(response)
      return if hidden_field_rejected?(response)

      Rails.logger.warn("[InSalesSync][Trigger] Failed to ensure visibility product=#{insales_product_id} status=#{response&.status}")
    end

    def hidden_field_rejected?(response)
      return false unless response
      return false unless [400, 422].include?(response.status)

      response.body.to_s.include?('is_hidden')
    end

    def success?(response)
      response && (200..299).cover?(response.status)
    end
  end
end
