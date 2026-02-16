# frozen_string_literal: true

module Insales
  class ExportProducts
    Result = Struct.new(:processed, :created, :updated, :errors, keyword_init: true)

    def self.call(product_id: nil, dry_run: false, collection_id: nil)
      new.call(product_id: product_id, dry_run: dry_run, collection_id: collection_id)
    end

    def initialize(client = Insales::InsalesClient.new)
      @client = client
      @product_field_catalog = Insales::ProductFieldCatalog.new(client)
    end

    def call(product_id:, dry_run:, collection_id:)
      scope = product_id.present? ? Product.where(id: product_id) : Product.all
      result = Result.new(processed: 0, created: 0, updated: 0, errors: 0)

      scope.find_each do |product|
        result.processed += 1
        export_product(product, dry_run, result, collection_id)
      end

      Rails.logger.info(
        "[InSales] Products export completed: processed=#{result.processed} " \
        "created=#{result.created} updated=#{result.updated} errors=#{result.errors}"
      )

      result
    end

    private

    attr_reader :client, :product_field_catalog

    def export_product(product, dry_run, result, collection_id)
      mapping = InsalesProductMapping.find_by(aura_product_id: product.id)
      product_field_values = if dry_run || !product_fields_enabled?
                               []
                             else
                               product_field_catalog.product_field_values_attributes(product)
                             end
      if product_fields_enabled? && !dry_run && product_field_values.empty?
        Rails.logger.warn("[InSales][Fields] No fields prepared for product=#{product.id} sku=#{product.sku}")
      end
      payload = build_payload(product, collection_id: collection_id, product_field_values: product_field_values)

      if dry_run
        mapping ? result.updated += 1 : result.created += 1
        return
      end

      if mapping
        update_response = client.put(
          "/admin/products/#{mapping.insales_product_id}.json",
          update_payload(product, collection_id: collection_id, product_field_values: product_field_values)
        )
        if collection_ids_rejected?(update_response)
          update_response = client.put(
            "/admin/products/#{mapping.insales_product_id}.json",
            update_payload(
              product,
              include_collection: false,
              collection_id: collection_id,
              product_field_values: product_field_values
            )
          )
        end

        unless response_success?(update_response)
          result.errors += 1
          return
        end

        variant_id = mapping.insales_variant_id || fetch_variant_id(mapping.insales_product_id)
        if variant_id
          variant_response = client.put("/admin/variants/#{variant_id}.json", variant_payload(product))
          if response_success?(variant_response)
            mapping.update!(insales_variant_id: variant_id)
          else
            result.errors += 1
            return
          end
        else
          result.errors += 1
          return
        end

        assign_to_collection(mapping.insales_product_id, collection_id)
        result.updated += 1
      else
        create_response = client.post('/admin/products.json', payload)
        if collection_ids_rejected?(create_response)
          create_response = client.post(
            '/admin/products.json',
            build_payload(
              product,
              include_collection: false,
              collection_id: collection_id,
              product_field_values: product_field_values
            )
          )
        end

        if response_success?(create_response)
          insales_id = extract_product_id(create_response.body)
          variant_id = extract_variant_id(create_response.body)
          if insales_id
            InsalesProductMapping.create!(
              aura_product_id: product.id,
              insales_product_id: insales_id,
              insales_variant_id: variant_id
            )
            assign_to_collection(insales_id, collection_id)
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

    def build_payload(product, include_collection: true, collection_id: nil, product_field_values: [])
      sku = product.sku.presence || product.code
      price = product.retail_price&.to_f
      quantity = total_stock(product)

      category_id = InsalesSetting.first&.category_id || ENV['INSALES_CATEGORY_ID']
      collection_ids = include_collection ? collection_ids_array(collection_id) : nil

      {
        product: {
          title: product.name,
          category_id: category_id.presence&.to_i,
          variants_attributes: [
            {
              sku: sku,
              price: price,
              quantity: quantity
            }
          ]
        }.tap do |p|
          p[:collection_ids] = collection_ids if collection_ids.present?
          p[:product_field_values_attributes] = product_field_values if product_field_values.present?
        end
      }
    end

    def update_payload(product, include_collection: true, collection_id: nil, product_field_values: [])
      category_id = InsalesSetting.first&.category_id || ENV['INSALES_CATEGORY_ID']
      collection_ids = include_collection ? collection_ids_array(collection_id) : nil

      {
        product: {
          title: product.name,
          category_id: category_id.presence&.to_i
        }.tap do |p|
          p[:collection_ids] = collection_ids if collection_ids.present?
          p[:product_field_values_attributes] = product_field_values if product_field_values.present?
        end
      }
    end

    def collection_ids_array(override)
      id = override.presence || InsalesSetting.first&.default_collection_id
      id.present? ? [id.to_i] : nil
    end

    def variant_payload(product)
      sku = product.sku.presence || product.code
      price = product.retail_price&.to_f
      quantity = total_stock(product)

      {
        variant: {
          sku: sku,
          price: price,
          quantity: quantity
        }
      }
    end

    def fetch_variant_id(insales_product_id)
      response = client.get("/admin/products/#{insales_product_id}.json")
      return nil unless response_success?(response)

      extract_variant_id(response.body)
    end

    def assign_to_collection(insales_product_id, override)
      id = override.presence || InsalesSetting.first&.default_collection_id
      return if id.blank?
      return unless collection_assignment_enabled?

      Rails.logger.info("[InSales] Assign product to collection #{id}")
      client.post("/admin/collections/#{id}/products.json", { product_id: insales_product_id })
    end

    def collection_assignment_enabled?
      ENV['INSALES_ASSIGN_COLLECTIONS'].to_s == '1'
    end

    def product_fields_enabled?
      ENV.fetch('INSALES_EXPORT_PRODUCT_FIELDS', '1') != '0'
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

    def extract_variant_id(body)
      return nil unless body.is_a?(Hash)

      variants = body['variants'] || body.dig('product', 'variants')
      variants&.first&.[]('id')
    end

    def collection_ids_rejected?(response)
      return false unless response
      return false unless [400, 422].include?(response.status)

      response.body.to_s.include?('collection_ids')
    end
  end
end
