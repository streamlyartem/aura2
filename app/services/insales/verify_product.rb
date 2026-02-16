# frozen_string_literal: true

module Insales
  class VerifyProduct
    Result = Struct.new(
      :ok,
      :message,
      :http_status,
      :http_endpoint,
      :verified_at,
      :stock_verify_skipped_reason,
      keyword_init: true
    )

    def initialize(client = Insales::InsalesClient.new)
      @client = client
    end

    def call(product:, insales_product_id:, insales_variant_id: nil, expected_category_id: nil, expected_collection_id: nil)
      response = client.get("/admin/products/#{insales_product_id}.json")
      return fail_result("GET product failed status=#{response&.status}") unless success?(response)

      product_body = response.body
      insales_product = product_body['product'] || product_body

      title_ok = insales_product['title'].to_s == product.name.to_s
      category_ok = expected_category_id.blank? || insales_product['category_id'].to_s == expected_category_id.to_s

      collection_ok = true
      if expected_collection_id.present?
        collection_ids = insales_product['collection_ids']
        if collection_ids.is_a?(Array)
          collection_ok = collection_ids.map(&:to_s).include?(expected_collection_id.to_s)
        end
      end

      variants = insales_product['variants'] || []
      return fail_result('Missing variants') if variants.empty?

      variant_id = insales_variant_id || variants.first['id']
      sku_expected = product.sku.presence || product.code
      sku_ok = variants.any? { |v| v['sku'].to_s == sku_expected.to_s }

      stock_verify = verify_variant(variant_id, product)

      unless title_ok && category_ok && collection_ok && sku_ok && stock_verify[:ok]
        message = build_failure_message(title_ok, category_ok, collection_ok, sku_ok, stock_verify)
        return fail_result(message, stock_verify[:skipped_reason])
      end

      Result.new(
        ok: true,
        message: 'verified',
        http_status: response.status,
        http_endpoint: "/admin/products/#{insales_product_id}.json",
        verified_at: Time.current,
        stock_verify_skipped_reason: stock_verify[:skipped_reason]
      )
    rescue StandardError => e
      fail_result("#{e.class}: #{e.message}")
    end

    private

    attr_reader :client

    def verify_variant(variant_id, product)
      return { ok: true, skipped_reason: 'variant_id_missing' } if variant_id.blank?

      response = client.get("/admin/variants/#{variant_id}.json")
      return { ok: true, skipped_reason: 'stock_verify_skipped' } unless success?(response)

      body = response.body['variant'] || response.body
      sku_expected = product.sku.presence || product.code
      price_expected = product.retail_price&.to_f
      quantity_expected = ProductStock.where(product_id: product.id).sum(:stock).to_f

      sku_ok = body['sku'].to_s == sku_expected.to_s
      price_ok = price_expected.nil? || body['price'].to_f == price_expected.to_f
      quantity_ok = body['quantity'].to_f == quantity_expected.to_f

      { ok: sku_ok && price_ok && quantity_ok, skipped_reason: nil }
    rescue StandardError
      { ok: false, skipped_reason: nil }
    end

    def success?(response)
      response && (200..299).cover?(response.status)
    end

    def fail_result(message, skipped_reason = nil)
      Result.new(
        ok: false,
        message: "Verify failed: #{message}",
        http_status: client.last_http_status,
        http_endpoint: client.last_http_endpoint,
        verified_at: Time.current,
        stock_verify_skipped_reason: skipped_reason
      )
    end

    def build_failure_message(title_ok, category_ok, collection_ok, sku_ok, stock_verify)
      parts = []
      parts << 'title' unless title_ok
      parts << 'category_id' unless category_ok
      parts << 'collection_id' unless collection_ok
      parts << 'sku' unless sku_ok
      parts << 'variant' unless stock_verify[:ok]
      parts.join(', ')
    end
  end
end
