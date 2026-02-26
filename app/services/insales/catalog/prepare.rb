# frozen_string_literal: true

module Insales
  module Catalog
    class Prepare
      BATCH_SIZE = 500
      PRICE_TYPE_COLUMNS = {
        'retail' => :retail_price,
        'small_wholesale' => :small_wholesale_price,
        'big_wholesale' => :large_wholesale_price,
        'wholesale_500_plus' => :five_hundred_plus_wholesale_price
      }.freeze

      Result = Struct.new(:processed, :ready, :skipped, :errors, keyword_init: true)

      def self.call
        new.call
      end

      def call
        result = Result.new(processed: 0, ready: 0, skipped: 0, errors: 0)

        products_scope.in_batches(of: BATCH_SIZE) do |batch_relation|
          products = batch_relation.to_a
          next if products.empty?

          stock_totals = ProductStock
                         .where(product_id: products.map(&:id), store_name: selected_store_names)
                         .group(:product_id)
                         .sum(:stock)

          rows = products.map do |product|
            attrs = build_row_attributes(product, stock_totals.fetch(product.id, 0))
            result.processed += 1
            case attrs[:status]
            when 'ready'
              result.ready += 1
            when 'skipped'
              result.skipped += 1
            else
              result.errors += 1
            end
            attrs
          end

          InsalesCatalogItem.upsert_all(rows, unique_by: :index_insales_catalog_items_on_product_id) if rows.any?
        end

        result
      end

      private

      def products_scope
        Product.select(
          :id,
          :sku,
          :code,
          :unit_type,
          :weight,
          :retail_price,
          :small_wholesale_price,
          :large_wholesale_price,
          :five_hundred_plus_wholesale_price
        )
      end

      def build_row_attributes(product, stock_total)
        now = Time.current
        sku_value = product.sku.presence || product.code

        status = 'ready'
        skip_reason = nil
        last_error = nil
        export_quantity = resolve_export_quantity(product, stock_total)
        prices_cents = resolve_prices_cents(product)

        if skip_without_sku? && sku_value.blank?
          status = 'skipped'
          skip_reason = 'no_sku'
        elsif skip_nonpositive_stock? && export_quantity <= 0
          status = 'skipped'
          skip_reason = 'nonpositive_stock'
        elsif prices_cents['retail'].blank?
          status = 'error'
          skip_reason = 'no_price'
          last_error = 'Retail price is missing'
        end

        {
          product_id: product.id,
          export_quantity: export_quantity,
          prices_cents: prices_cents,
          status: status,
          skip_reason: skip_reason,
          prepared_at: now,
          last_error: last_error,
          created_at: now,
          updated_at: now
        }
      end

      def resolve_export_quantity(product, stock_total)
        if product.unit_type == 'weight'
          stock_total.to_d.positive? ? 1 : 0
        else
          [stock_total.to_d.floor, 0].max
        end
      end

      def resolve_prices_cents(product)
        PRICE_TYPE_COLUMNS.each_with_object({}) do |(price_type, column), memo|
          price_rub = product.public_send(column)
          cents = price_to_item_cents(product, price_rub)
          memo[price_type] = cents if cents.present?
        end
      end

      def price_to_item_cents(product, price_rub)
        return nil if price_rub.blank?

        if product.unit_type == 'weight'
          weight_g = product.weight.to_d
          return nil if weight_g <= 0

          (price_rub.to_d * 100 * weight_g).round.to_i
        else
          (price_rub.to_d * 100).round.to_i
        end
      end

      def setting
        @setting ||= InsalesSetting.first
      end

      def selected_store_names
        @selected_store_names ||= begin
          names = setting&.allowed_store_names_list
          names = [MoyskladClient::TEST_STORE_NAME] if names.blank?
          names
        end
      end

      def skip_without_sku?
        setting&.skip_products_without_sku
      end

      def skip_nonpositive_stock?
        setting&.skip_products_with_nonpositive_stock
      end
    end
  end
end
