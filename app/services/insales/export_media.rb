# frozen_string_literal: true

require 'base64'
require 'json'

module Insales
  class ExportMedia
    Result = Struct.new(
      :images_selected,
      :images_uploaded,
      :images_updated,
      :images_deleted,
      :images_skipped,
      :images_errors,
      :videos_selected,
      :videos_uploaded,
      :videos_updated,
      :videos_deleted,
      :videos_skipped,
      :last_media_error,
      :video_urls,
      keyword_init: true
    )

    def self.call(product_id:, dry_run: false)
      new.call(product_id: product_id, dry_run: dry_run)
    end

    def initialize(client = Insales::InsalesClient.new)
      @client = client
    end

    def call(product_id:, dry_run:)
      result = Result.new(
        images_selected: 0,
        images_uploaded: 0,
        images_updated: 0,
        images_deleted: 0,
        images_skipped: 0,
        images_errors: 0,
        videos_selected: 0,
        videos_uploaded: 0,
        videos_updated: 0,
        videos_deleted: 0,
        videos_skipped: 0,
        last_media_error: nil,
        video_urls: []
      )

      product = Product.find_by(id: product_id)
      return result unless product

      mapping = InsalesProductMapping.find_by(aura_product_id: product.id)
      return result unless mapping

      media_items = InsalesMediaItem.where(aura_product_id: product.id, export_to_insales: true).order(:position, :created_at)
      image_items = media_items.select { |m| m.kind == 'image' }
      video_items = media_items.select { |m| m.kind == 'video' }

      result.images_selected = image_items.size
      result.videos_selected = video_items.size

      sync_images(image_items, mapping.insales_product_id, result, dry_run)
      sync_videos(video_items, mapping.insales_product_id, result, dry_run)
      delete_stale_media(mapping.insales_product_id, media_items, result, dry_run)

      result
    rescue StandardError => e
      result.last_media_error = "#{e.class}: #{e.message}"
      result.images_errors += 1
      result
    end

    private

    attr_reader :client

    def sync_images(items, insales_product_id, result, dry_run)
      items.each do |media_item|
        image = media_item.image
        if image.nil? || !image.file.attached?
          result.images_errors += 1
          result.last_media_error = "Missing image file for media_item #{media_item.id}"
          next
        end

        checksum = media_item.checksum || image.file.blob&.checksum
        mapping = InsalesMediaMapping.find_by(aura_media_item_id: media_item.id)

        if mapping&.last_synced_checksum.present? && mapping.last_synced_checksum == checksum
          result.images_skipped += 1
          next
        end

        if dry_run
          mapping ? result.images_updated += 1 : result.images_uploaded += 1
          next
        end

        delete_existing_image(mapping, insales_product_id, result)
        upload_image(media_item, image, insales_product_id, result, checksum)
      end
    end

    def upload_image(media_item, image, insales_product_id, result, checksum)
      bytes = image.file.download
      filename = image.file.filename.to_s
      encoded = Base64.strict_encode64(bytes)

      field_candidates = %w[attachment data file content]
      tried = []

      loop do
        field = (field_candidates - tried).first
        break unless field

        tried << field
        response = client.post(
          "/admin/products/#{insales_product_id}/images.json",
          { image: { field => encoded, filename: filename, title: filename } }
        )

        if response_success?(response)
          insales_image_id = extract_image_id(response.body)
          mapping = InsalesMediaMapping.find_or_initialize_by(aura_media_item_id: media_item.id)
          mapping.assign_attributes(
            insales_product_id: insales_product_id,
            insales_media_id: insales_image_id,
            kind: 'image',
            position: media_item.position,
            last_synced_checksum: checksum,
            last_synced_at: Time.current
          )
          mapping.save!
          result.images_uploaded += 1
          return
        end

        next if response&.status.to_i >= 400 && response&.status.to_i < 500
        break
      end

      result.images_errors += 1
    end

    def delete_existing_image(mapping, insales_product_id, result)
      return unless mapping&.insales_media_id

      response = client.delete("/admin/products/#{insales_product_id}/images/#{mapping.insales_media_id}.json")
      if response_success?(response)
        result.images_deleted += 1
      else
        result.images_skipped += 1
      end
    end

    def sync_videos(items, insales_product_id, result, dry_run)
      urls = items.map(&:url).compact
      result.video_urls = urls
      return if urls.empty?

      if dry_run
        result.videos_uploaded += urls.size
        return
      end

      description = fetch_description(insales_product_id)
      new_description = build_description_with_videos(description, urls)
      return if new_description == description

      response = client.put("/admin/products/#{insales_product_id}.json", { product: { description: new_description } })
      if response_success?(response)
        result.videos_updated += urls.size
      else
        result.videos_skipped += urls.size
        result.last_media_error = "Video update failed status=#{response&.status}"
      end

      items.each do |media_item|
        mapping = InsalesMediaMapping.find_or_initialize_by(aura_media_item_id: media_item.id)
        mapping.assign_attributes(
          insales_product_id: insales_product_id,
          kind: 'video',
          position: media_item.position,
          last_synced_checksum: media_item.checksum,
          last_synced_at: Time.current
        )
        mapping.save!
      end
    end

    def delete_stale_media(insales_product_id, enabled_items, result, dry_run)
      enabled_ids = enabled_items.map(&:id)
      InsalesMediaMapping.where(insales_product_id: insales_product_id).find_each do |mapping|
        next if enabled_ids.include?(mapping.aura_media_item_id)

        if dry_run
          result.images_deleted += 1 if mapping.kind == 'image'
          result.videos_deleted += 1 if mapping.kind == 'video'
          next
        end

        if mapping.kind == 'image' && mapping.insales_media_id.present?
          response = client.delete("/admin/products/#{insales_product_id}/images/#{mapping.insales_media_id}.json")
          if response_success?(response)
            result.images_deleted += 1
            mapping.destroy!
          else
            result.images_skipped += 1
          end
        elsif mapping.kind == 'video'
          result.videos_deleted += 1
          mapping.destroy!
        end
      end
    end

    def fetch_description(insales_product_id)
      response = client.get("/admin/products/#{insales_product_id}.json")
      return '' unless response_success?(response)

      body = response.body
      product = body['product'] || body
      product['description'].to_s
    end

    def build_description_with_videos(description, urls)
      start_marker = '<!-- AURA_VIDEOS_START -->'
      end_marker = '<!-- AURA_VIDEOS_END -->'
      block = urls.map { |u| "<p><a href=\"#{u}\" target=\"_blank\">#{u}</a></p>" }.join

      if description.include?(start_marker) && description.include?(end_marker)
        before = description.split(start_marker).first
        after = description.split(end_marker).last
        "#{before}#{start_marker}#{block}#{end_marker}#{after}"
      else
        [description, start_marker, block, end_marker].join
      end
    end

    def extract_image_id(body)
      payload = body.is_a?(Hash) ? body : JSON.parse(body.to_s) rescue {}
      payload['id'] || payload.dig('image', 'id')
    end

    def response_success?(response)
      response && (200..299).cover?(response.status)
    end
  end
end
