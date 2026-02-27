# frozen_string_literal: true

require 'base64'
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

      images = product.images.order(:created_at).limit(3)

      images.each do |image|
        result.processed += 1

        if dry_run
          result.uploaded += 1
          next
        end

        upload_image(image, mapping.insales_product_id, result)
      rescue ActiveStorage::FileNotFoundError => e
        result.skipped += 1
        Rails.logger.warn("[InSales] Image export skipped for #{image.id}: #{e.class}")
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
      encoded = Base64.strict_encode64(bytes)

      field_candidates = %w[attachment data file content]
      tried = []

      loop do
        field = next_field(field_candidates, tried)
        break unless field

        tried << field
        Rails.logger.info("[InSales] Image upload attempt field=#{field} image_id=#{image.id}")

        response = client.post(
          "/admin/products/#{insales_product_id}/images.json",
          build_payload(field, encoded, filename)
        )

        Rails.logger.info("[InSales] Image upload status=#{response&.status} body=#{short_body(response&.body)}")

        if response_success?(response)
          result.uploaded += 1
          return
        end

        if response && response.status.to_i >= 400 && response.status.to_i < 500
          hinted = hint_field(response.body, field_candidates)
          if hinted && !tried.include?(hinted)
            tried << field
            field_candidates = [hinted] + (field_candidates - [hinted])
            next
          end
          break
        end
      end

      result.errors += 1
    end

    def build_payload(field, encoded, filename)
      {
        image: {
          field => encoded,
          filename: filename,
          title: filename
        }
      }
    end

    def next_field(candidates, tried)
      (candidates - tried).first
    end

    def hint_field(body, candidates)
      text = body.to_s
      candidates.find { |c| text.include?(c) }
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
