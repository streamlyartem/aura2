# frozen_string_literal: true

module Insales
  class ExportProducts
    Result = Struct.new(:processed, :created, :updated, :errors, keyword_init: true)

    def self.call(product_id: nil, dry_run: false, collection_id: nil)
      new.call(product_id: product_id, dry_run: dry_run, collection_id: collection_id)
    end

    def self.skip_reason_for(product)
      new.send(:skip_reason_for, product)
    end

    def initialize(client = Insales::InsalesClient.new)
      @client = client
      @product_property_catalog = Insales::ProductPropertyCatalog.new
      @category_resolver = Insales::CategoryResolver.new(client)
    end

    def call(product_id:, dry_run:, collection_id:)
      scope = if product_id.present?
                Product.where(id: product_id)
              else
                Product.where(id: InsalesCatalogItem.ready.select(:product_id))
              end
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

    attr_reader :client, :product_property_catalog

    def export_product(product, dry_run, result, collection_id)
      reason = skip_reason_for(product)
      if reason
        log_skip(product, reason)
        return
      end

      catalog_item = ready_catalog_item_for(product)
      unless catalog_item
        result.errors += 1
        Rails.logger.warn("[InSales] catalog not prepared product=#{product.id}")
        return
      end

      mapping = InsalesProductMapping.find_by(aura_product_id: product.id)
      existing_product_body = {}
      if mapping.present? && !dry_run
        existing_product_response = fetch_product(mapping.insales_product_id)
        if existing_product_response&.status.to_i == 404
          Rails.logger.warn("[InSales] Stale mapping detected for product=#{product.id} insales_product_id=#{mapping.insales_product_id}, recreating")
          mapping.destroy!
          mapping = nil
        elsif !response_success?(existing_product_response)
          log_response('fetch_product_failed', product, existing_product_response)
          result.errors += 1
          return
        else
          existing_product_body = existing_product_response.body
        end
      end

      properties_attributes = build_properties_attributes(product, existing_product_body)
      payload = build_payload(
        product,
        collection_id: collection_id,
        properties_attributes: properties_attributes,
        catalog_item: catalog_item
      )

      if dry_run
        mapping ? result.updated += 1 : result.created += 1
        return
      end

      if mapping
        update_response = client.put(
          "/admin/products/#{mapping.insales_product_id}.json",
          update_payload(
            product,
            collection_id: collection_id,
            properties_attributes: properties_attributes
          )
        )
        if collection_ids_rejected?(update_response)
          update_response = client.put(
            "/admin/products/#{mapping.insales_product_id}.json",
            update_payload(
              product,
              include_collection: false,
              collection_id: collection_id,
              properties_attributes: properties_attributes
            )
          )
        end

        if update_response&.status.to_i == 404
          Rails.logger.warn("[InSales] Stale mapping detected for product=#{product.id} insales_product_id=#{mapping.insales_product_id}, recreating")
          mapping.destroy!
          create_product(product, payload, collection_id, properties_attributes, catalog_item, result)
          return
        end

        unless response_success?(update_response)
          log_response('update_product_failed', product, update_response)
          result.errors += 1
          return
        end

        variant_id = mapping.insales_variant_id || extract_variant_id(existing_product_body) || fetch_variant_id(mapping.insales_product_id)
        if variant_id
          variant_response = client.put("/admin/variants/#{variant_id}.json", variant_payload(product, catalog_item: catalog_item))
          if response_success?(variant_response)
            mapping.update!(insales_variant_id: variant_id)
          else
            log_response('update_variant_failed', product, variant_response)
            result.errors += 1
            return
          end
        else
          Rails.logger.warn("[InSales] Variant id missing for product=#{product.id} insales_product_id=#{mapping.insales_product_id}")
          result.errors += 1
          return
        end

        sync_collection_assignment(product, mapping.insales_product_id)
        result.updated += 1
      else
        create_product(product, payload, collection_id, properties_attributes, catalog_item, result)
      end
    rescue StandardError => e
      result.errors += 1
      Rails.logger.error("[InSales] Product export failed for #{product.id}: #{e.class} - #{e.message}")
    end

    def build_payload(product, include_collection: true, collection_id: nil, properties_attributes: [], catalog_item:)
      sku = product.sku.presence || product.code
      price = catalog_price(catalog_item, 'retail', required: true)
      price2 = catalog_price(catalog_item, 'small_wholesale')
      price3 = catalog_price(catalog_item, 'big_wholesale')
      quantity = catalog_quantity(catalog_item)

      collection_id_from_mapping = resolved_collection_id(product)
      category_id = default_category_id
      collection_ids = include_collection ? collection_ids_array(collection_id, collection_id_from_mapping) : nil

      {
        product: {
          title: product.name,
          category_id: category_id.presence&.to_i,
          variants_attributes: [
            {
              sku: sku,
              price: price,
              price2: price2,
              price3: price3,
              quantity: quantity
            }
          ]
        }.tap do |p|
          p[:collection_ids] = collection_ids if collection_ids.present?
          p[:properties_attributes] = properties_attributes if properties_attributes.present?
        end
      }
    end

    def update_payload(product, include_collection: true, collection_id: nil, properties_attributes: [])
      collection_id_from_mapping = resolved_collection_id(product)
      category_id = default_category_id
      collection_ids = include_collection ? collection_ids_array(collection_id, collection_id_from_mapping) : nil

      {
        product: {
          title: product.name,
          category_id: category_id.presence&.to_i
        }.tap do |p|
          p[:collection_ids] = collection_ids if collection_ids.present?
          p[:properties_attributes] = properties_attributes if properties_attributes.present?
        end
      }
    end

    def collection_ids_array(override, mapped = nil)
      ids = []
      ids << mapped.to_i if mapped.present?
      id = override.presence || InsalesSetting.first&.default_collection_id
      ids << id.to_i if id.present?
      ids.uniq!
      ids.presence
    end

    def variant_payload(product, catalog_item:)
      sku = product.sku.presence || product.code
      price = catalog_price(catalog_item, 'retail', required: true)
      price2 = catalog_price(catalog_item, 'small_wholesale')
      price3 = catalog_price(catalog_item, 'big_wholesale')
      quantity = catalog_quantity(catalog_item)

      {
        variant: {
          sku: sku,
          price: price,
          price2: price2,
          price3: price3,
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
      ids = collection_ids_array(override)
      return if ids.blank?
      return unless collection_assignment_enabled?

      ids.each do |id|
        Rails.logger.info("[InSales] Assign product to collection #{id}")
        client.post("/admin/collections/#{id}/products.json", { product_id: insales_product_id })
      end
    end

    def create_product(product, payload, collection_id, properties_attributes, catalog_item, result)
      create_response = client.post('/admin/products.json', payload)
      if collection_ids_rejected?(create_response)
        create_response = client.post(
          '/admin/products.json',
          build_payload(
            product,
            include_collection: false,
            collection_id: collection_id,
            properties_attributes: properties_attributes,
            catalog_item: catalog_item
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
          sync_collection_assignment(product, insales_id)
          result.created += 1
        else
          log_response('create_product_missing_id', product, create_response)
          result.errors += 1
        end
      else
        log_response('create_product_failed', product, create_response)
        result.errors += 1
      end
    end

    def collection_assignment_enabled?
      ENV['INSALES_ASSIGN_COLLECTIONS'].to_s == '1'
    end

    def sync_collection_assignment(product, insales_product_id)
      return unless collection_assignment_enabled?

      resolver = Insales::ResolveCollectionId.new(client)
      collection_id = begin
        resolver.resolve(product.path_name)
      rescue StandardError => e
        Rails.logger.warn(
          "[InSales][Collections] Resolve failed product=#{product.id} path=#{product.path_name.inspect} " \
          "error=#{e.class} #{e.message}"
        )
        nil
      end
      collection_id = InsalesSetting.first&.default_collection_id if collection_id.blank?
      return if collection_id.blank?

      attacher = Insales::AttachProductToCollection.new(client)
      attacher.ensure_attached(product_id: insales_product_id, collection_id: collection_id)
    end

    def fetch_product(insales_product_id)
      client.get("/admin/products/#{insales_product_id}.json")
    end

    def total_stock(product)
      store_names = InsalesSetting.first&.allowed_store_names_list
      store_names = [MoyskladClient::TEST_STORE_NAME] if store_names.blank?
      ProductStock.where(product_id: product.id, store_name: store_names).sum(:stock).to_f
    end

    def skip_reason_for(product)
      setting = InsalesSetting.first
      return nil unless setting

      sku_value = product.sku.presence || product.code
      if setting.skip_products_without_sku && sku_value.blank?
        return 'skipped_no_sku'
      end

      if setting.skip_products_with_nonpositive_stock && total_stock(product).to_f <= 0
        return 'skipped_nonpositive_stock'
      end

      nil
    end

    def log_skip(product, reason)
      Rails.logger.info("[InSales][Skip] product=#{product.id} reason=#{reason}")
    end

    def resolved_collection_id(product)
      mapping_id = category_resolver.category_id_for(product)
      return mapping_id if mapping_id.present?

      nil
    end

    def default_category_id
      fallback = InsalesSetting.first&.category_id || ENV['INSALES_CATEGORY_ID']
      if fallback.blank?
        Rails.logger.warn("[InSales][Category] Missing default category_id for export")
      end
      fallback
    end

    def category_resolver
      @category_resolver
    end

    def response_success?(response)
      response && (200..299).cover?(response.status)
    end

    def log_response(label, product, response)
      Rails.logger.warn(
        "[InSales] #{label} product=#{product.id} " \
        "status=#{response&.status} body=#{truncate_body(response&.body)}"
      )
    end

    def truncate_body(body)
      body.to_s.byteslice(0, 300)
    end

    def ready_catalog_item_for(product)
      item = InsalesCatalogItem.find_by(product_id: product.id)
      return item if item&.status == 'ready'

      nil
    end

    def catalog_price(catalog_item, key, required: false)
      cents = catalog_item.prices_cents&.dig(key)
      if cents.blank?
        raise ArgumentError, "catalog #{key} price missing" if required

        return nil
      end

      (cents.to_d / 100).to_f
    end

    def catalog_quantity(catalog_item)
      catalog_item.export_quantity.to_i
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

    def extract_properties(body)
      return [] unless body.is_a?(Hash)

      properties = body['properties'] || body.dig('product', 'properties')
      return [] unless properties.is_a?(Array)

      properties.select { |item| item.is_a?(Hash) }
    end

    def build_properties_attributes(product, existing_product_body)
      product_property_catalog.properties_attributes(
        product,
        existing_properties: extract_properties(existing_product_body)
      )
    end

    def collection_ids_rejected?(response)
      return false unless response
      return false unless [400, 422].include?(response.status)

      response.body.to_s.include?('collection_ids')
    end
  end
end
