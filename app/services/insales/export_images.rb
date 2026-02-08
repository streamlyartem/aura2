# frozen_string_literal: true

require 'json'

module Insales
  class ExportImages
    Result = Struct.new(:processed, :uploaded, :skipped, :errors, keyword_init: true)

    def self.call(product_id:, dry_run: false)
      new.call(product_id: product_id, dry_run: dry_run)
    end

    def initialize(client = Insales::InsalesClient.new)
      @client = client
    end

    def call(product_id:, dry_run:)
      raise ArgumentError, 'product_id is required' if product_id.blank?

      result = Result.new(processed: 0, uploaded: 0, skipped: 0, errors: 0)
      product = Product.find_by(id: product_id)
      return result unless product

      mapping = InsalesProductMapping.find_by(aura_product_id: product.id)
      unless mapping
        Rails.logger.warn("[InSales] No product mapping for #{product.id}")
        return result
      end

      images = product.images.order(:created_at).limit(2)

      images.each do |image|
        result.processed += 1

        if InsalesImageMapping.exists?(aura_image_id: image.id)
          result.skipped += 1
          next
        end

        if dry_run
          result.uploaded += 1
          next
        end

        upload_image(image, mapping.insales_product_id, result)
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

    def response_success?(response)
      response && (200..299).cover?(response.status)
    end

    def upload_image(image, insales_product_id, result)
      bytes = image.file.download
      filename = image.file.filename.to_s
      content_type = image.file.blob.content_type || 'application/octet-stream'

      fields = { 'image[title]' => filename }
      field_names = %w[image[attachment] image[file]]

      field_names.each do |field_name|
        Rails.logger.info("[InSales] Image upload attempt field=#{field_name} image_id=#{image.id}")
        response = client.post_multipart(
          "/admin/products/#{insales_product_id}/images.json",
          fields: fields,
          file_field_name: field_name,
          filename: filename,
          content_type: content_type,
          file_bytes: bytes
        )

        if response_success?(response)
          insales_image_id = extract_image_id(response.body)
          InsalesImageMapping.create!(
            aura_image_id: image.id,
            insales_product_id: insales_product_id,
            insales_image_id: insales_image_id
          )
          result.uploaded += 1
          return
        end

        if response.status.to_i >= 400 && response.status.to_i < 500
          Rails.logger.warn("[InSales] Image upload failed status=#{response.status} body=#{short_body(response.body)}")
          break
        end
      end

      result.errors += 1
    end

    def extract_image_id(body)
      payload = parse_json(body)
      return nil unless payload.is_a?(Hash)

      payload['id'] || payload.dig('image', 'id')
    end

    def parse_json(body)
      return body if body.is_a?(Hash)

      JSON.parse(body.to_s)
    rescue JSON::ParserError
      nil
    end

    def short_body(body)
      body.to_s.byteslice(0, 300)
    end
  end
end
