# frozen_string_literal: true

require 'erb'

require 'net/http'
require 'uri'

module Insales
  class SyncProductMedia
    Result = Struct.new(
      :photos_in_aura,
      :photos_uploaded,
      :photos_skipped,
      :photos_errors,
      :verified_admin,
      :verified_storefront,
      :status,
      :last_error,
      :storefront_url,
      keyword_init: true
    )

    def initialize(client = Insales::InsalesClient.new)
      @client = client
      @fetch_cache = {}
    end

    def call(product:, insales_product_id:)
      photos = product.images.select(&:image?).sort_by(&:created_at).first(3)

      state = InsalesMediaSyncState.find_or_initialize_by(product_id: product.id)
      state.assign_attributes(
        insales_product_id: insales_product_id,
        photos_in_aura: photos.size,
        photos_uploaded: 0,
        verified_admin: false,
        verified_storefront: false,
        status: 'in_progress',
        last_error: nil,
        synced_at: nil
      )
      state.save!

      if photos.empty?
        state.update!(
          photos_uploaded: 0,
          verified_admin: true,
          verified_storefront: true,
          status: 'success',
          last_error: nil,
          synced_at: Time.current
        )

        return Result.new(
          photos_in_aura: 0,
          photos_uploaded: 0,
          photos_skipped: 0,
          photos_errors: 0,
          verified_admin: true,
          verified_storefront: true,
          status: 'success',
          last_error: nil,
          storefront_url: nil
        )
      end

      upload_result = Insales::ExportImages.call(product_id: product.id, dry_run: false)

      verified_admin, image_urls, admin_error = verify_admin(insales_product_id, upload_result.uploaded)
      if verified_admin
        verified_storefront, storefront_error, storefront_url = verify_storefront(insales_product_id, image_urls)
      else
        verified_storefront = false
        storefront_error = nil
        storefront_url = nil
      end

      status = if verified_admin && verified_storefront
                 'success'
               elsif admin_error.present? || storefront_error.present?
                 'error'
               else
                 'in_progress'
               end

      last_error = admin_error.presence || storefront_error

      state.update!(
        photos_uploaded: upload_result.uploaded,
        verified_admin: verified_admin,
        verified_storefront: verified_storefront,
        status: status,
        last_error: last_error,
        synced_at: Time.current
      )

      Result.new(
        photos_in_aura: photos.size,
        photos_uploaded: upload_result.uploaded,
        photos_skipped: upload_result.skipped,
        photos_errors: upload_result.errors,
        verified_admin: verified_admin,
        verified_storefront: verified_storefront,
        status: status,
        last_error: last_error,
        storefront_url: storefront_url
      )
    rescue StandardError => e
      state&.update!(status: 'error', last_error: "#{e.class}: #{e.message}", synced_at: Time.current)
      Result.new(status: 'error', last_error: "#{e.class}: #{e.message}")
    end

    private

    attr_reader :client

    def verify_admin(insales_product_id, expected_count)
      response = client.get("/admin/products/#{insales_product_id}/images.json")
      unless success?(response)
        return [false, [], "Admin verify failed status=#{response&.status}"]
      end

      images = response.body['images'] || response.body || []
      urls = images.map { |img| img['url'] || img['original_url'] || img['src'] }.compact

      if urls.size < expected_count
        return [false, urls, "Admin images count #{urls.size} < expected #{expected_count}"]
      end

      [true, urls.first(expected_count), nil]
    end

    def verify_storefront(insales_product_id, image_urls)
      product_response = client.get("/admin/products/#{insales_product_id}.json")
      return [false, "Storefront product fetch failed status=#{product_response&.status}", nil] unless success?(product_response)

      insales_product = product_response.body['product'] || product_response.body
      storefront_url = build_storefront_url(insales_product)
      return [false, 'Storefront URL missing', nil] if storefront_url.blank?

      html_response = fetch_url(storefront_url)
      unless html_response[:status] == 200
        return [false, "Storefront GET failed status=#{html_response[:status]}", storefront_url]
      end

      html = html_response[:body].to_s
      image_urls.each do |url|
        unless html_includes_url?(html, url)
          return [false, "Storefront HTML missing image #{url}", storefront_url]
        end

        image_response = fetch_url(url)
        return [false, "Storefront image GET failed status=#{image_response[:status]}", storefront_url] unless image_response[:status] == 200
      end

      [true, nil, storefront_url]
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
        escaped_path = path.sub(%r{^/}, '').split('/').map { |seg| ERB::Util.url_encode(seg) }.join('/')
        URI.join("#{base}/", escaped_path).to_s
      end
    end

    def storefront_base_url
      setting = InsalesSetting.first
      base = setting&.base_url || ENV['INSALES_BASE_URL']
      return nil if base.blank?

      base = "https://#{base}" unless base.start_with?('http')
      base.chomp('/')
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

    def html_includes_url?(html, url)
      return false if html.blank? || url.blank?

      filename = url.split('/').last.to_s
      variants = [
        url,
        url.sub(%r{^https?://}, ''),
        url.sub(%r{^https?://}, '//'),
        filename
      ]
      variants.any? { |variant| html.include?(variant) }
    end

    def success?(response)
      response && (200..299).cover?(response.status)
    end
  end
end
