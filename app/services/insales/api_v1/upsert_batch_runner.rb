# frozen_string_literal: true

module Insales
  module ApiV1
    class UpsertBatchRunner
      def initialize(contract: UpsertItemContract.new)
        @contract = contract
      end

      def call(run:, items:)
        run.update!(status: 'running', started_at: Time.current, total_items: items.size)

        errors = []
        created = updated = unchanged = skipped = failed = 0

        items.each do |raw_item|
          validation = contract.validate(raw_item)
          unless validation[:valid]
            skipped += 1
            errors << build_error(validation[:item], 'VALIDATION_ERROR', 'Invalid payload', validation[:errors])
            next
          end

          item = validation[:item]
          result = upsert_product(item)
          case result
          when :created then created += 1
          when :updated then updated += 1
          when :unchanged then unchanged += 1
          else
            failed += 1
            errors << build_error(item, 'INTERNAL_ERROR', 'Unknown upsert result')
          end
        rescue StandardError => e
          failed += 1
          errors << build_error(item || raw_item, 'INTERNAL_ERROR', e.message)
        ensure
          run.increment!(:processed)
        end

        run.update!(
          status: failed.positive? ? 'failed' : 'success',
          finished_at: Time.current,
          created_count: created,
          updated_count: updated,
          unchanged_count: unchanged,
          skipped_count: skipped,
          failed_count: failed,
          error_items: errors,
          last_error: errors.last&.dig(:message)
        )
      rescue StandardError => e
        run.update!(status: 'failed', finished_at: Time.current, last_error: "#{e.class}: #{e.message}")
        raise
      end

      private

      attr_reader :contract

      def upsert_product(item)
        product = find_product(item)
        attrs = mapped_attrs(item)

        if product.nil?
          product = Product.new
          product.id = item['external_id'] if uuid?(item['external_id'])
          product.assign_attributes(attrs)
          product.ms_id = item['external_id'] if item['external_id'].present? && product.ms_id.blank?
          product.save!
          upsert_stock(product, item)
          return :created
        end

        changed = product.assign_attributes(attrs)
        changed = product.changed?
        product.save! if changed
        stock_changed = upsert_stock(product, item)

        if changed || stock_changed
          :updated
        else
          :unchanged
        end
      end

      def find_product(item)
        external_id = item['external_id'].to_s

        Product.find_by(id: external_id) ||
          Product.find_by(ms_id: external_id) ||
          Product.find_by(sku: item['sku'])
      end

      def mapped_attrs(item)
        {
          sku: item['sku'].to_s.strip,
          name: item['name'].to_s.strip,
          retail_price: (item['price_minor'].to_d / 100),
          weight: item['weight_grams'],
          length: item['length_cm'],
          tone: item['tone'],
          structure: item['structure'],
          color: item['color']
        }
      end

      def upsert_stock(product, item)
        stock_value = Integer(item['stock_qty'])
        stock = ProductStock.find_or_initialize_by(product_id: product.id, store_name: 'API v1')
        previous = stock.stock.to_d
        stock.assign_attributes(stock: stock_value, free_stock: stock_value, synced_at: Time.current)
        changed = stock.new_record? || previous != stock_value.to_d
        stock.save! if changed
        changed
      end

      def uuid?(value)
        value.to_s.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i)
      end

      def build_error(item, code, message, details = nil)
        {
          external_id: item&.dig('external_id') || item&.dig(:external_id),
          code: code,
          message: message,
          details: details
        }
      end
    end
  end
end
