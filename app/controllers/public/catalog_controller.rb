# frozen_string_literal: true

module Public
  class CatalogController < ApplicationController
    CATALOG_IMAGE_MAX_BYTES = 900.kilobytes
    DETAIL_IMAGE_MAX_BYTES = 1.5.megabytes
    CATALOG_VIDEO_MAX_BYTES = 4.megabytes
    DETAIL_VIDEO_MAX_BYTES = 12.megabytes

    before_action :set_cors_headers

    def products
      limit = params.fetch(:limit, 40).to_i.clamp(1, 1000)
      scope = base_scope
      records = scope.limit(limit * 4)
      catalog_items_by_product_id = InsalesCatalogItem.ready.where(product_id: records.map(&:id)).index_by(&:product_id)

      payload = records.filter_map do |product|
        serialize_product(product, catalog_items_by_product_id[product.id])
      end
      payload = payload.first(limit)

      render json: {
        products: payload,
        count: payload.size,
        generated_at: Time.current.iso8601
      }
    end

    def show
      product = base_scope.find_by(id: params[:id])
      return render json: { error: 'Product not found' }, status: :not_found unless product

      payload = serialize_product_detail(product)
      return render json: { error: 'Product not found' }, status: :not_found unless payload

      render json: {
        product: payload,
        generated_at: Time.current.iso8601
      }
    end

    private

    def base_scope
      ready_product_ids = InsalesCatalogItem.ready.order(export_updated_at: :desc, updated_at: :desc).pluck(:product_id)

      Product
        .where(id: ready_product_ids)
        .joins(images: :file_attachment)
        .includes(:product_stocks, images: { file_attachment: :blob })
        .distinct
        .order(updated_at: :desc)
    end

    def serialize_product(product, catalog_item)
      media = product.images.select { |image| image.file.attached? }.sort_by(&:created_at)
      image_media = pick_light_images(media.select(&:image?), limit: 2, max_bytes: CATALOG_IMAGE_MAX_BYTES)
      return nil if image_media.empty?

      video_media = pick_light_video(media.select(&:video?), max_bytes: CATALOG_VIDEO_MAX_BYTES)
      image_urls = image_media.map { |image| media_url(image) }.compact
      return nil if image_urls.empty?

      video_url = video_media && media_url(video_media)

      {
        id: product.id,
        name: product.name.presence || product.sku.presence || "Товар #{product.id}",
        sku: product.sku.to_s,
        type: product_type(product),
        length: product.length&.to_f&.round || 0,
        weight: weight_grams(product),
        color: product.color.presence || 'Не указан',
        tone: product.tone.presence || '—',
        structure: product.structure.presence || 'Не указана',
        retail_price: retail_price(product, catalog_item),
        price: retail_price(product, catalog_item),
        image: image_urls.first,
        images: image_urls,
        video: video_url,
        in_stock: in_stock?(product),
        badge: product.ombre? ? 'Омбре' : nil,
        created_at: product.created_at
      }
    end

    def serialize_product_detail(product)
      media = product.images.select { |image| image.file.attached? }.sort_by(&:created_at)
      image_media = pick_light_images(media.select(&:image?), limit: 12, max_bytes: DETAIL_IMAGE_MAX_BYTES)
      return nil if image_media.empty?

      video_media = pick_light_video(media.select(&:video?), max_bytes: DETAIL_VIDEO_MAX_BYTES)
      image_urls = image_media.map { |image| media_url(image) }.compact
      return nil if image_urls.empty?

      video_url = video_media && media_url(video_media)
      catalog_item = InsalesCatalogItem.ready.find_by(product_id: product.id)

      {
        id: product.id,
        name: product.name.presence || product.sku.presence || "Товар #{product.id}",
        sku: product.sku.to_s,
        type: product_type(product),
        length: product.length&.to_f&.round || 0,
        weight: weight_grams(product),
        color: product.color.presence || 'Не указан',
        tone: product.tone.presence || '—',
        structure: product.structure.presence || 'Не указана',
        retail_price: retail_price(product, catalog_item),
        price: retail_price(product, catalog_item),
        image: image_urls.first,
        images: image_urls,
        video: video_url,
        in_stock: in_stock?(product),
        description: product_description(product),
        created_at: product.created_at,
        updated_at: product.updated_at
      }
    end

    def media_url(image_id)
      image = image_id.is_a?(Image) ? image_id : Image.find_by(id: image_id)
      return nil unless image&.file&.attached?

      # For storefront performance we prefer direct object-store URLs over Rails proxy streaming.
      image.service_url
    rescue StandardError
      fallback_media_url(image&.id || image_id)
    end

    def fallback_media_url(image_id)
      "#{request.base_url}/public/images/#{image_id}"
    end

    def product_price(product)
      raw_price = product.retail_price || product.min_price || product.purchase_price
      return 0 unless raw_price

      raw_price.to_f.round
    end

    def retail_price(product, catalog_item)
      cents = catalog_item&.prices_cents&.dig('retail')
      return (cents.to_i / 100.0).round if cents.present?

      product_price(product)
    end

    def weight_grams(product)
      product.unit_weight_g&.to_f&.round || product.weight&.to_f&.round || 0
    end

    def in_stock?(product)
      return true if product.ms_stock_qty.to_i.positive? || product.ms_stock_g.to_i.positive?

      product.product_stocks.any? { |stock| stock.free_stock.to_f.positive? || stock.stock.to_f.positive? }
    end

    def product_type(product)
      return 'Омбре' if product.ombre?

      path = product.path_name.to_s.downcase
      name = product.name.to_s.downcase
      return 'Ленты' if path.include?('лент') || name.include?('лент')

      'Срезы'
    end

    def product_description(product)
      "#{product_type(product)} из натуральных волос. Длина #{product.length&.to_f&.round || 0} см, цвет #{product.color.presence || 'не указан'}."
    end

    def set_cors_headers
      response.set_header('Access-Control-Allow-Origin', '*')
    end

    def pick_light_images(images, limit:, max_bytes:)
      return [] if images.empty?

      light = images.select { |image| image_size_bytes(image) <= max_bytes }
      source = light.presence || images
      source.sort_by { |image| image_size_bytes(image) }.first(limit)
    end

    def pick_light_video(videos, max_bytes:)
      return nil if videos.empty?

      light = videos.select { |video| image_size_bytes(video) <= max_bytes }
      source = light.presence || videos
      source.min_by { |video| image_size_bytes(video) }
    end

    def image_size_bytes(image)
      image.file.blob.byte_size.to_i
    rescue StandardError
      0
    end
  end
end
