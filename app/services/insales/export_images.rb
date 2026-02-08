# frozen_string_literal: true

module Insales
  class ExportImages
    Result = Struct.new(:processed, :uploaded, :skipped, :errors, keyword_init: true)

    def self.call(product_id:, dry_run: false, limit: nil)
      new.call(product_id: product_id, dry_run: dry_run, limit: limit)
    end

    def initialize(client = Insales::InsalesClient.new)
      @client = client
    end

    def call(product_id:, dry_run:, limit: nil)
      raise ArgumentError, 'product_id is required' if product_id.blank?

      result = Result.new(processed: 0, uploaded: 0, skipped: 0, errors: 0)
      product = Product.find_by(id: product_id)
      return result unless product

      mapping = InsalesProductMapping.find_by(aura_product_id: product.id)
      unless mapping
        Rails.logger.warn("[InSales] No product mapping for #{product.id}")
        return result
      end

      images = product.images.order(:created_at)
      images = images.limit(limit) if limit.present?

      images.each do |image|
        result.processed += 1

        if InsalesImageMapping.exists?(aura_image_id: image.id)
          result.skipped += 1
          next
        end

        src = image_src(image)
        if src.blank?
          Rails.logger.warn "[InSales] Image #{image.id} has no public URL"
          result.skipped += 1
          next
        end

        if dry_run
          result.uploaded += 1
          next
        end

        response = client.post("/admin/products/#{mapping.insales_product_id}/images.json", { image: { src: src } })
        if response_success?(response)
          insales_image_id = extract_image_id(response.body)
          InsalesImageMapping.create!(
            aura_image_id: image.id,
            insales_product_id: mapping.insales_product_id,
            insales_image_id: insales_image_id
          )
          result.uploaded += 1
        else
          result.errors += 1
        end
      rescue StandardError => e
        result.errors += 1
        Rails.logger.error("[InSales] Image export failed for #{image.id}: #{e.class} - #{e.message}")
      end

      Rails.logger.info(
        "[InSales] Images export completed: processed=#{result.processed} " \
        "uploaded=#{result.uploaded} skipped=#{result.skipped} errors=#{result.errors}"
      )

      result
    end

    private

    attr_reader :client

    def image_src(image)
      mode = InsalesSetting.first&.image_url_mode || ENV.fetch('INSALES_IMAGE_URL_MODE', 'service_url')
      mode == 'rails_url' ? image.url : image.service_url
    end

    def response_success?(response)
      response && (200..299).cover?(response.status)
    end

    def extract_image_id(body)
      return nil unless body.is_a?(Hash)

      body['id'] || body.dig('image', 'id')
    end
  end
end
