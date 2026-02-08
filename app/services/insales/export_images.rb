# frozen_string_literal: true

require 'digest'
require 'json'

module Insales
  class ExportImages
    Result = Struct.new(:processed, :uploaded, :skipped, :errors, keyword_init: true)

    def self.call(scope: Product.all, limit: nil, since: nil, product_id: nil, only_missing: false, dry_run: false)
      new.call(scope: scope, limit: limit, since: since, product_id: product_id, only_missing: only_missing,
               dry_run: dry_run)
    end

    def initialize(client = Insales::InsalesClient.new(
      base_url: ENV.fetch('INSALES_BASE_URL'),
      login: ENV.fetch('INSALES_LOGIN'),
      password: ENV.fetch('INSALES_PASSWORD')
    ))
      @client = client
    end

    def call(scope:, limit:, since:, product_id:, only_missing:, dry_run:)
      result = Result.new(processed: 0, uploaded: 0, skipped: 0, errors: 0)
      filtered = apply_filters(scope, limit, since, product_id)
      image_limit = product_id.present? ? limit : nil

      each_scope(filtered, limit).each do |product|
        mapping = InsalesProductMapping.find_by(aura_product_id: product.id)
        next unless mapping

        export_images_for(product, mapping.insales_product_id, image_limit, only_missing, dry_run, result)
      end

      Rails.logger.info(
        "[InSales] Images export completed: processed=#{result.processed} " \
        "uploaded=#{result.uploaded} skipped=#{result.skipped} errors=#{result.errors}"
      )

      result
    end

    private

    attr_reader :client

    def apply_filters(scope, limit, since, product_id)
      scope = scope.where(id: product_id) if product_id.present?
      scope = scope.where('updated_at >= ?', since) if since.present?
      scope = scope.limit(limit) if limit.present? && product_id.blank?
      scope
    end

    def each_scope(scope, limit)
      if limit.present?
        scope.order(:id).each
      else
        scope.find_each
      end
    end

    def export_images_for(product, insales_product_id, image_limit, only_missing, dry_run, result)
      images = product.images.order(:created_at)
      images = images.limit(image_limit) if image_limit.present?

      images.each do |image|
        result.processed += 1

        mapping = InsalesImageMapping.find_by(aura_image_id: image.id)
        if mapping && only_missing
          result.skipped += 1
          next
        end

        src = image_src(image)
        if src.blank?
          Rails.logger.warn "[InSales] Image #{image.id} has no public URL"
          result.skipped += 1
          next
        end

        src_hash = digest(src)
        if mapping && mapping.src_hash == src_hash
          result.skipped += 1
          next
        end

        if dry_run
          result.uploaded += 1
          next
        end

        response = client.post("/admin/products/#{insales_product_id}/images.json", { image: { src: src } })
        if response_success?(response)
          insales_image_id = extract_image_id(response.body)
          upsert_mapping(mapping, image, insales_product_id, insales_image_id, src_hash)
          result.uploaded += 1
        else
          result.errors += 1
        end
      rescue StandardError => e
        result.errors += 1
        Rails.logger.error("[InSales] Image export failed for #{image.id}: #{e.class} - #{e.message}")
      end
    end

    def image_src(image)
      mode = ENV.fetch('INSALES_IMAGE_URL_MODE', 'service_url')
      case mode
      when 'rails_url'
        image.url
      else
        image.service_url
      end
    end

    def upsert_mapping(mapping, image, insales_product_id, insales_image_id, src_hash)
      if mapping
        mapping.update!(
          insales_product_id: insales_product_id,
          insales_image_id: insales_image_id,
          src_hash: src_hash,
          last_synced_at: Time.current
        )
      else
        InsalesImageMapping.create!(
          aura_image_id: image.id,
          insales_product_id: insales_product_id,
          insales_image_id: insales_image_id,
          src_hash: src_hash,
          last_synced_at: Time.current
        )
      end
    end

    def digest(value)
      Digest::SHA256.hexdigest(value.to_s)
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
