# frozen_string_literal: true

module Insales
  module ApiV1
    module InboundOrders
      class Processor
        RETRYABLE_HTTP_STATUSES = [429].freeze
        RETRYABLE_RANGE = (500..599).freeze

        def process(event_id:)
          event = ExternalOrderEvent.includes(external_order: :external_order_items).find(event_id)
          return if event.processing_status == 'processed'

          order = event.external_order
          raise 'External order not found for event' if order.nil?

          if paid?(order)
            order.update!(status: 'paid')
            op = find_or_create_operation!(order)
            process_operation!(op) if Insales::ApiV1::FeatureFlags.order_fulfillment_enabled?
          else
            order.update!(status: order.status.presence || 'awaiting_payment')
          end

          event.update!(processing_status: 'processed', processed_at: Time.current, processing_error: nil)
        rescue StandardError => e
          event&.update!(processing_status: 'failed', processing_error: "#{e.class}: #{e.message}", processed_at: Time.current)
          raise
        end

        private

        def paid?(order)
          value = order.payment_status.to_s.downcase
          %w[paid paid_full succeeded success].include?(value)
        end

        def find_or_create_operation!(order)
          key = "insales:#{order.external_order_id}:paid"
          ExternalFulfillmentOperation.find_or_create_by!(idempotency_key: key) do |op|
            op.external_order = order
            op.operation_type = 'write_off'
            op.status = 'queued'
            op.comment = "Продажа в InSales — заказ #{order.external_order_number.presence || order.external_order_id}"
          end
        end

        def process_operation!(operation)
          return if operation.status == 'succeeded'

          operation.update!(status: 'processing', attempts: operation.attempts.to_i + 1, last_error: nil)

          doc_ids = []
          with_stock_change_suppressed do
            operation.external_order.external_order_items.each do |item|
              product = item.product || Product.find_by(sku: item.sku)
              raise "Product not found for SKU=#{item.sku}" if product.nil?

              stock = pick_stock(product)
              raise "No stock in selling stores for SKU=#{item.sku}" if stock.nil?

              quantity = item.quantity.to_d
              raise "Insufficient stock for SKU=#{item.sku}" if quantity <= 0 || stock.stock.to_d < quantity

              response = MoyskladClient.new.create_demand(
                product,
                quantity.to_f,
                description: operation.comment
              )
              status = response&.status.to_i
              unless status.in?([200, 201])
                raise_retryable_if_needed!(status)
                raise "MoySklad demand failed status=#{status}"
              end

              body = response.respond_to?(:body) ? response.body : nil
              doc_ids << body['id'] if body.is_a?(Hash) && body['id'].present?

              stock.withdraw_stock(quantity)
            end
          end

          operation.update!(
            status: 'succeeded',
            ms_document_id: doc_ids.compact.join(',').presence || operation.ms_document_id,
            next_retry_at: nil
          )
        rescue RetryableOperationError => e
          operation.update!(
            status: 'failed_retryable',
            last_error: e.message,
            next_retry_at: Time.current + retry_backoff(operation.attempts)
          )
          raise
        rescue StandardError => e
          operation.update!(status: 'failed_terminal', last_error: e.message)
          raise
        end

        def pick_stock(product)
          stores = InsalesSetting.first&.allowed_store_names_list
          stores = [MoyskladClient::TEST_STORE_NAME] if stores.blank?

          product.product_stocks.where(store_name: stores).order(stock: :desc).detect { |row| row.stock.to_d.positive? }
        end

        def retry_backoff(attempts)
          base_minutes = [1, 5, 15, 60]
          base_minutes[[attempts.to_i - 1, base_minutes.length - 1].min].minutes
        end

        def raise_retryable_if_needed!(status)
          return unless RETRYABLE_HTTP_STATUSES.include?(status) || RETRYABLE_RANGE.cover?(status)

          raise RetryableOperationError, "MoySklad retryable failure status=#{status}"
        end

        def with_stock_change_suppressed
          Current.with(skip_stock_change_processor_enqueue: true) { yield }
        end

        class RetryableOperationError < StandardError; end
      end
    end
  end
end
