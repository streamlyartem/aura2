# frozen_string_literal: true

module AuraProducts
  class StatusSnapshot
    CACHE_KEY = 'aura_products:status_snapshot'
    CACHE_TTL = 5.minutes

    TypeStats = Struct.new(:type, :count, keyword_init: true)

    def self.call(force: false)
      new.call(force: force)
    end

    def call(force: false)
      return build_snapshot if force

      Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) { build_snapshot }
    end

    private

    def build_snapshot
      selected_store_names = MoyskladStore.where(selected_for_import: true).pluck(:name)
      selected_stock_scope = ProductStock.where(store_name: selected_store_names)

      products = Product.select(:id, :path_name, :unit_type).to_a
      product_type_stats = classify_products(products)
      typed_count = product_type_stats.sum { |entry| entry[:count] }

      {
        generated_at: Time.current,
        total_products: products.size,
        products_with_stock_rows: ProductStock.distinct.count(:product_id),
        products_on_selected_stores: selected_stock_scope.distinct.count(:product_id),
        products_with_positive_stock_on_selected_stores: selected_stock_scope.where('stock > 0').distinct.count(:product_id),
        products_typed: typed_count,
        products_untyped: products.size - typed_count,
        insales_catalog_ready: InsalesCatalogItem.where(status: 'ready').count,
        insales_catalog_skipped: InsalesCatalogItem.where(status: 'skipped').count,
        insales_catalog_error: InsalesCatalogItem.where(status: 'error').count,
        product_type_stats: product_type_stats,
        selected_store_names: selected_store_names
      }
    end

    def classify_products(products)
      types = AuraProductType.active.ordered.to_a
      return [] if types.empty?

      counters = Hash.new(0)
      resolver = AuraProducts::TypeResolver.new(types: types)

      products.each do |product|
        type = resolver.resolve(product)
        counters[type.code] += 1 if type
      end

      types.filter_map do |type|
        count = counters[type.code]
        next if count.zero?

        {
          type: type,
          count: count
        }
      end
    end
  end
end
