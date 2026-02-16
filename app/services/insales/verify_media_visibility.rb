# frozen_string_literal: true

require 'digest'
require 'net/http'
require 'uri'

module Insales
  class VerifyMediaVisibility
    Result = Struct.new(
      :status,
      :message,
      :photos_count,
      :videos_count,
      :last_error,
      keyword_init: true
    )

    def initialize(client = Insales::InsalesClient.new)
      @client = client
      @fetch_cache = {}
    end

    def call(product:)
      mapping = InsalesProductMapping.find_by(aura_product_id: product.id)
      unless mapping
        return persist_failure(product, 'Missing InSales product mapping')
      end

      aura_images = product.images.select(&:image?)
      aura_videos = product.images.select(&:video?)

      status_record = InsalesMediaStatus.find_or_initialize_by(product_id: product.id)
      status_record.assign_attributes(
        photos_count: aura_images.size,
        videos_count: aura_videos.size,
        status: 'in_progress',
        last_error: nil,
        last_checked_at: Time.current
      )
      status_record.save!

      product_response = client.get("/admin/products/#{mapping.insales_product_id}.json")
      return persist_failure(product, "InSales product fetch failed status=#{product_response&.status}") unless success?(product_response)

      insales_product = product_response.body['product'] || product_response.body
      description = insales_product['description'].to_s

      images_response = client.get("/admin/products/#{mapping.insales_product_id}/images.json")
      return persist_failure(product, "InSales images fetch failed status=#{images_response&.status}") unless success?(images_response)

      insales_images = images_response.body['images'] || images_response.body || []
      checksum_to_urls = build_insales_image_checksum_map(insales_images)

      storefront_url = build_storefront_url(insales_product)
      storefront_html = nil
      storefront_status = nil
      if storefront_url.present?
        storefront_response = fetch_url(storefront_url)
        storefront_status = storefront_response[:status]
        storefront_html = storefront_response[:body] if storefront_status == 200
      end

      items = []

      aura_images.each do |image|
        items << verify_image_item(product, image, checksum_to_urls, storefront_html)
      end

      aura_videos.each do |video|
        items << verify_video_item(product, video, description, storefront_html)
      end

      apply_storefront_failure(items, storefront_url, storefront_status) if storefront_html.nil?

      finalize_status(product, items, status_record)
    rescue StandardError => e
      persist_failure(product, "#{e.class}: #{e.message}")
    end

    private

    attr_reader :client

    def verify_image_item(product, image, checksum_to_urls, storefront_html)
      source_key = "aura_image:#{image.id}"
      checksum = aura_image_checksum(image)
      matched_url = checksum_to_urls[checksum]&.first

      item = InsalesMediaStatusItem.find_or_initialize_by(product_id: product.id, source_key: source_key)
      item.assign_attributes(
        kind: 'image',
        source_checksum: checksum,
        source_url: nil,
        api_ok: matched_url.present?,
        api_verified_at: Time.current,
        api_error: matched_url.present? ? nil : 'Image not found in InSales API',
        storefront_ok: false,
        storefront_verified_at: nil,
        storefront_error: nil,
        status: 'in_progress'
      )

      if matched_url.present? && storefront_html.present?
        storefront_result = verify_storefront_url(matched_url, storefront_html)
        item.storefront_ok = storefront_result[:ok]
        item.storefront_verified_at = Time.current
        item.storefront_error = storefront_result[:error]
      end

      item.status = item.api_ok && item.storefront_ok ? 'success' : (item.api_error.present? || item.storefront_error.present? ? 'error' : 'in_progress')
      item.save!
      item
    end

    def verify_video_item(product, video, description, storefront_html)
      video_url = video.url
      source_key = "url:#{video_url}"
      api_ok = video_url.present? && description.include?(video_url)

      item = InsalesMediaStatusItem.find_or_initialize_by(product_id: product.id, source_key: source_key)
      item.assign_attributes(
        kind: 'video',
        source_checksum: nil,
        source_url: video_url,
        api_ok: api_ok,
        api_verified_at: Time.current,
        api_error: api_ok ? nil : 'Video URL missing in InSales description',
        storefront_ok: false,
        storefront_verified_at: nil,
        storefront_error: nil,
        status: 'in_progress'
      )

      if api_ok && storefront_html.present?
        storefront_result = verify_storefront_url(video_url, storefront_html)
        item.storefront_ok = storefront_result[:ok]
        item.storefront_verified_at = Time.current
        item.storefront_error = storefront_result[:error]
      end

      item.status = item.api_ok && item.storefront_ok ? 'success' : (item.api_error.present? || item.storefront_error.present? ? 'error' : 'in_progress')
      item.save!
      item
    end

    def apply_storefront_failure(items, storefront_url, storefront_status)
      error_message = storefront_url.blank? ? 'Storefront URL missing' : "Storefront fetch failed status=#{storefront_status}"
      items.each do |item|
        item.storefront_ok = false
        item.storefront_verified_at = Time.current
        item.storefront_error = error_message
        item.status = item.api_ok ? 'error' : 'in_progress'
        item.save!
      end
    end

    def finalize_status(product, items, status_record)
      errors = items.select { |item| item.status == 'error' }
      in_progress = items.select { |item| item.status == 'in_progress' }

      status_record.last_api_verified_at = Time.current
      status_record.last_storefront_verified_at = Time.current

      if errors.any?
        status_record.status = 'error'
        status_record.last_error = errors.first.api_error || errors.first.storefront_error
      elsif in_progress.any?
        status_record.status = 'in_progress'
      else
        status_record.status = 'success'
      end

      status_record.save!

      Result.new(
        status: status_record.status,
        message: status_record.last_error,
        photos_count: status_record.photos_count,
        videos_count: status_record.videos_count,
        last_error: status_record.last_error
      )
    end

    def persist_failure(product, message)
      status_record = InsalesMediaStatus.find_or_initialize_by(product_id: product.id)
      status_record.assign_attributes(
        status: 'error',
        last_error: message,
        last_checked_at: Time.current,
        last_api_verified_at: Time.current
      )
      status_record.save!
      Result.new(status: 'error', message: message, last_error: message)
    end

    def build_insales_image_checksum_map(insales_images)
      checksum_to_urls = Hash.new { |h, k| h[k] = [] }

      insales_images.each do |image|
        url = image['url'] || image['original_url'] || image['src'] || image['file_url']
        next if url.blank?

        response = fetch_url(url)
        next unless response[:status] == 200

        checksum = Digest::MD5.base64digest(response[:body])
        checksum_to_urls[checksum] << url
      end

      checksum_to_urls
    end

    def aura_image_checksum(image)
      return image.file.blob.checksum if image.file.attached? && image.file.blob&.checksum.present?
      return nil unless image.file.attached?

      Digest::MD5.base64digest(image.file.download)
    end

    def build_storefront_url(insales_product)
      base = storefront_base_url
      return nil if base.blank?

      raw_url = insales_product['url'] || insales_product['permalink'] || insales_product['handle']
      return base if raw_url.blank?

      if raw_url.start_with?('http')
        raw_url
      else
        path = raw_url.start_with?('/') ? raw_url : "/product/#{raw_url}"
        URI.join("#{base}/", path.sub(%r{^/}, '')).to_s
      end
    end

    def storefront_base_url
      setting = InsalesSetting.first
      base = setting&.base_url || ENV['INSALES_BASE_URL']
      return nil if base.blank?

      base = "https://#{base}" unless base.start_with?('http')
      base.chomp('/')
    end

    def verify_storefront_url(url, html)
      return { ok: false, error: 'Storefront HTML missing URL' } unless html_includes_url?(html, url)

      response = fetch_url(url)
      return { ok: false, error: "Storefront GET failed status=#{response[:status]}" } unless response[:status] == 200

      { ok: true, error: nil }
    end

    def html_includes_url?(html, url)
      return false if html.blank? || url.blank?

      variants = [
        url,
        url.sub(%r{^https?://}, ''),
        url.sub(%r{^https?://}, '//')
      ]
      variants.any? { |variant| html.include?(variant) }
    end

    def fetch_url(url)
      return @fetch_cache[url] if @fetch_cache.key?(url)

      response = fetch_url_uncached(url)
      @fetch_cache[url] = response
      response
    end

    def fetch_url_uncached(url, limit = 3)
      uri = URI.parse(url)
      raise ArgumentError, "Invalid URL: #{url}" if uri.host.blank?

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = 5
      http.read_timeout = 10

      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)

      if response.is_a?(Net::HTTPRedirection) && limit.positive?
        return fetch_url_uncached(response['location'], limit - 1)
      end

      { status: response.code.to_i, body: response.body }
    rescue StandardError => e
      { status: nil, body: nil, error: "#{e.class}: #{e.message}" }
    end

    def success?(response)
      response && (200..299).cover?(response.status)
    end
  end
end
