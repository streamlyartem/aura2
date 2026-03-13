# frozen_string_literal: true

module Public
  class CatalogController < ApplicationController
    before_action :set_cors_headers

    def products
      limit = params.fetch(:limit, 40).to_i.clamp(1, 1000)
      scope = base_scope
      records = scope.limit(limit * 4)

      payload = records.filter_map { |product| serialize_product(product) }
      payload = payload.first(limit)

      render json: {
        products: payload,
        count: payload.size,
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

    def serialize_product(product)
      media = product.images.select { |image| image.file.attached? }.sort_by(&:created_at)
      image_media = media.select(&:image?)
      return nil if image_media.empty?

      video_media = media.select(&:video?)
      image_urls = image_media.first(2).map { |image| media_url(image) }.compact
      return nil if image_urls.empty?

      video_url = (video_media.first && media_url(video_media.first)) || demo_video_url

      {
        id: product.id,
        name: product.name.presence || product.sku.presence || "Товар #{product.id}",
        type: product_type(product),
        length: product.length&.to_f&.round || 0,
        color: product.color.presence || 'Не указан',
        tone: product.tone.presence || '—',
        structure: product.structure.presence || 'Не указана',
        price: product_price(product),
        image: image_urls.first,
        images: image_urls,
        video: video_url,
        in_stock: in_stock?(product),
        badge: product.ombre? ? 'Омбре' : nil,
        created_at: product.created_at
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

    def demo_video_url
      ENV.fetch('CATALOG_DEMO_VIDEO_URL', 'https://5cufml.stackhero-network.com/website/hero1.m4v')
    end

    def set_cors_headers
      response.set_header('Access-Control-Allow-Origin', '*')
    end
  end
end
