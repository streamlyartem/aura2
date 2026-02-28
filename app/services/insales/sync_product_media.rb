# frozen_string_literal: true

require 'erb'

require 'net/http'
require 'uri'

module Insales
  class SyncProductMedia
    ADMIN_VERIFY_ATTEMPTS = 5
    STOREFRONT_VERIFY_ATTEMPTS = 4
    VERIFY_RETRY_DELAY = 1.5
    PROCESSING_ERROR_PREFIX = 'processing:'

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
      selected_media = select_media(product)
      photos = selected_media.select(&:image?).sort_by(&:created_at).first(3)

      unless media_images_enabled?
        state = InsalesMediaSyncState.find_or_initialize_by(product_id: product.id)
        state.assign_attributes(
          insales_product_id: insales_product_id,
          photos_in_aura: photos.size,
          photos_uploaded: 0,
          verified_admin: false,
          verified_storefront: false,
          status: 'skipped',
          last_error: 'images_sync_disabled',
          synced_at: Time.current
        )
        state.save!
        return Result.new(status: 'skipped', last_error: 'images_sync_disabled')
      end

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

      existing_images, admin_list_error = fetch_admin_images(insales_product_id)
      if admin_list_error.present?
        state.update!(
          status: 'error',
          last_error: admin_list_error,
          synced_at: Time.current
        )
        return Result.new(status: 'error', last_error: admin_list_error)
      end

      cleanup_error = remove_existing_images(insales_product_id, existing_images)
      if cleanup_error.present?
        state.update!(
          status: 'error',
          last_error: cleanup_error,
          synced_at: Time.current
        )
        return Result.new(status: 'error', last_error: cleanup_error)
      end

      upload_result = Insales::ExportImages.call(product_id: product.id, dry_run: false, media_items: photos)

      verified_admin, image_urls, admin_error = verify_admin(insales_product_id, photos.size)
      if verified_admin
        verified_storefront, storefront_error, storefront_url = verify_storefront(insales_product_id, image_urls)
      else
        verified_storefront = false
        storefront_error = nil
        storefront_url = nil
      end

      status = if verified_admin && verified_storefront
                 'success'
               elsif transient_error?(admin_error, storefront_error)
                 'in_progress'
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

    def fetch_admin_images(insales_product_id)
      response = client.get("/admin/products/#{insales_product_id}/images.json")
      return [[], "Admin images fetch failed status=#{response&.status}"] unless success?(response)

      [extract_images(response.body), nil]
    end

    def remove_existing_images(insales_product_id, remote_images)
      errors = []

      remote_images.each do |image|
        image_id = image['id'] || image[:id]
        next if image_id.blank?

        debug_media("Delete old image product=#{insales_product_id} image_id=#{image_id}")

        response = delete_remote_image(insales_product_id, image_id)
        next if response_success_or_not_found?(response)

        errors << "id=#{image_id}: status=#{response&.status || 'n/a'}"
      end

      return nil if errors.empty?

      "Failed to delete remote images (#{errors.join(', ')})"
    end

    def delete_remote_image(insales_product_id, image_id)
      paths = [
        "/admin/products/#{insales_product_id}/images/#{image_id}.json",
        "/admin/products/images/#{image_id}.json"
      ]

      last_response = nil
      paths.each do |path|
        response = client.delete(path)
        last_response = response
        return response if response_success_or_not_found?(response)
      end

      last_response
    end

    def response_success_or_not_found?(response)
      response && ((200..299).cover?(response.status) || response.status.to_i == 404)
    end

    def verify_admin(insales_product_id, expected_count)
      urls = []
      last_status = nil

      ADMIN_VERIFY_ATTEMPTS.times do |attempt|
        response = client.get("/admin/products/#{insales_product_id}/images.json")
        last_status = response&.status
        unless success?(response)
          return [false, [], "Admin verify failed status=#{last_status}"]
        end

        images = extract_images(response.body)
        urls = images.filter_map { |img| normalize_remote_url(img['url'] || img['original_url'] || img['src']) }
        processing = images_processing?(images, urls)

        debug_media("Verify admin attempt=#{attempt + 1} #{urls.size}/#{expected_count} processing=#{processing} product=#{insales_product_id}")

        return [true, urls.first(expected_count), nil] if urls.size == expected_count && !processing

        break if attempt == ADMIN_VERIFY_ATTEMPTS - 1

        sleep VERIFY_RETRY_DELAY
      end

      return [false, urls, processing_error("Admin images count #{urls.size} < expected #{expected_count}")] if urls.size < expected_count
      return [false, urls, processing_error("Admin images are still processing")] if urls.any? { |url| loading_placeholder_url?(url) }

      [false, urls, "Admin images count #{urls.size} != expected #{expected_count}"]
    end

    def verify_storefront(insales_product_id, image_urls)
      product_response = client.get("/admin/products/#{insales_product_id}.json")
      return [false, "Storefront product fetch failed status=#{product_response&.status}", nil] unless success?(product_response)

      insales_product = product_response.body['product'] || product_response.body
      storefront_url = build_storefront_url(insales_product)
      return [false, 'Storefront URL missing', nil] if storefront_url.blank?

      last_reason = nil

      STOREFRONT_VERIFY_ATTEMPTS.times do |attempt|
        html_response = fetch_url(storefront_url, force: attempt.positive?)
        unless html_response[:status] == 200
          last_reason = "Storefront GET failed status=#{html_response[:status]}"
          break if attempt == STOREFRONT_VERIFY_ATTEMPTS - 1

          sleep VERIFY_RETRY_DELAY
          next
        end

        html = html_response[:body].to_s
        missing_image = false

        image_urls.each do |url|
          unless html_includes_url?(html, url)
            last_reason = "Storefront HTML missing image #{url}"
            missing_image = true
            break
          end

          image_response = fetch_url(url, force: attempt.positive?)
          unless image_response[:status] == 200
            last_reason = "Storefront image GET failed status=#{image_response[:status]}"
            missing_image = true
            break
          end
        end

        unless missing_image
          debug_media("Verify storefront OK product=#{insales_product_id}")
          return [true, nil, storefront_url]
        end

        break if attempt == STOREFRONT_VERIFY_ATTEMPTS - 1

        sleep VERIFY_RETRY_DELAY
      end

      debug_media("Verify storefront pending product=#{insales_product_id} reason=#{last_reason}")
      [false, processing_error(last_reason || 'Storefront image visibility pending'), storefront_url]
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

    def fetch_url(url, force: false)
      return { status: nil, body: nil, error: 'blank_url' } if url.blank?
      return fetch_url_uncached(url) if force
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
      ExternalHttpConfig.apply_net_http!(
        http,
        service: :insales,
        open_timeout: 5,
        read_timeout: 10
      )

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

    def normalize_remote_url(url)
      return nil if url.blank?

      if url.start_with?('http://', 'https://')
        url
      elsif url.start_with?('/')
        base = storefront_base_url
        base.present? ? URI.join("#{base}/", url.delete_prefix('/')).to_s : nil
      else
        url
      end
    rescue URI::InvalidURIError
      nil
    end

    def images_processing?(images, urls)
      images.any? { |img| img['image_processing'] } || urls.any? { |url| loading_placeholder_url?(url) }
    end

    def loading_placeholder_url?(url)
      url.to_s.include?('/images/loading.gif')
    end

    def processing_error(message)
      "#{PROCESSING_ERROR_PREFIX} #{message}"
    end

    def transient_error?(*errors)
      errors.compact.any? { |error| error.to_s.start_with?(PROCESSING_ERROR_PREFIX) }
    end

    def extract_images(body)
      case body
      when Array
        body.select { |item| item.is_a?(Hash) }
      when Hash
        list = body['images'] || body['product_images'] || body.dig('product', 'images')
        return [] unless list.is_a?(Array)

        list.select { |item| item.is_a?(Hash) }
      else
        []
      end
    end

    def debug_media(message)
      return unless ENV['INSALES_HTTP_DEBUG'].to_s == '1'

      Rails.logger.info("[InSales][MEDIA] #{message}")
    end

    def success?(response)
      response && (200..299).cover?(response.status)
    end

    def select_media(product)
      images = media_images_enabled? ? product.images.select(&:image?) : []
      videos = media_videos_enabled? ? product.images.select(&:video?) : []
      if videos.any?
        Rails.logger.info("[InSales][MEDIA] Video sync is enabled, but video upload is not supported yet. Skipping #{videos.size} items.")
      end

      (images + videos).sort_by(&:created_at).first(3)
    end

    def media_images_enabled?
      setting = InsalesSetting.first
      return true if setting.nil?

      setting.sync_images_enabled?
    end

    def media_videos_enabled?
      setting = InsalesSetting.first
      return false if setting.nil?

      setting.sync_videos_enabled?
    end
  end
end
