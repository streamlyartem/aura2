# frozen_string_literal: true

module Insales
  class ExportProducts
    Result = Struct.new(:processed, :created, :updated, :errors, keyword_init: true)

    def self.call(product_id: nil, dry_run: false)
      new.call(product_id: product_id, dry_run: dry_run)
    end

    def initialize(client = Insales::InsalesClient.new(
      base_url: ENV.fetch('INSALES_BASE_URL'),
      login: ENV.fetch('INSALES_LOGIN'),
      password: ENV.fetch('INSALES_PASSWORD')
    ))
      @client = client
    end

    def call(product_id:, dry_run:)
      scope = product_id.present? ? Product.where(id: product_id) : Product.all
      result = Result.new(processed: 0, created: 0, updated: 0, errors: 0)

      scope.find_each do |product|
        result.processed += 1
        export_product(product, dry_run, result)
      end

      Rails.logger.info(
        "[InSales] Products export completed: processed=#{result.processed} " \
        "created=#{result.created} updated=#{result.updated} errors=#{result.errors}"
      )

      result
    end

    private

    attr_reader :client

    def export_product(product, dry_run, result)
      mapping = InsalesProductMapping.find_by(aura_product_id: product.id)
      payload = build_payload(product)

      if dry_run
        mapping ? result.updated += 1 : result.created += 1
        return
      end

      if mapping
        response = client.put("/admin/products/#{mapping.insales_product_id}.json", payload)
        if response_success?(response)
          mapping.touch
          result.updated += 1
        else
          result.errors += 1
        end
      else
        response = client.post('/admin/products.json', payload)
        if response_success?(response)
          insales_id = extract_product_id(response.body)
          if insales_id
            InsalesProductMapping.create!(aura_product_id: product.id, insales_product_id: insales_id)
            result.created += 1
          else
            result.errors += 1
          end
        else
          result.errors += 1
        end
      end
    rescue StandardError => e
      result.errors += 1
      Rails.logger.error("[InSales] Product export failed for #{product.id}: #{e.class} - #{e.message}")
    end

    def build_payload(product)
      sku = product.sku.presence || product.code
      price = product.retail_price&.to_f
      quantity = total_stock(product)

      category_id = ENV['INSALES_CATEGORY_ID'].presence

      {
        product: {
          title: product.name,
          category_id: category_id&.to_i,
          variants_attributes: [
            {
              sku: sku,
              price: price,
              quantity: quantity
            }
          ]
        }
      }
    end

    def total_stock(product)
      ProductStock.where(product_id: product.id).sum(:stock).to_f
    end

    def response_success?(response)
      response && (200..299).cover?(response.status)
    end

    def extract_product_id(body)
      return nil unless body.is_a?(Hash)

      body['id'] || body.dig('product', 'id')
    end
  end
end
