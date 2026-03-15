# frozen_string_literal: true

module Insales
  module ApiV1
    module InboundOrders
      class Ingestor
        Result = Struct.new(:event, :order, :replay, keyword_init: true)

        def call(payload:, source: 'insales')
          data = payload.to_h.deep_stringify_keys
          source_event_id = extract_source_event_id(data)
          raise Insales::ApiV1::ErrorResponse.new(code: 'VALIDATION_ERROR', message: 'source_event_id is required', status: :unprocessable_entity) if source_event_id.blank?

          existing = ExternalOrderEvent.find_by(source: source, source_event_id: source_event_id)
          return Result.new(event: existing, order: existing&.external_order, replay: true) if existing

          order_payload = extract_order_payload(data)
          external_order_id = extract_external_order_id(order_payload)
          raise Insales::ApiV1::ErrorResponse.new(code: 'VALIDATION_ERROR', message: 'order.id is required', status: :unprocessable_entity) if external_order_id.blank?

          ActiveRecord::Base.transaction do
            order = upsert_order(source: source, order_payload: order_payload, external_order_id: external_order_id, payload: data)
            replace_items!(order: order, order_payload: order_payload)

            event = ExternalOrderEvent.create!(
              source: source,
              source_event_id: source_event_id,
              external_order: order,
              event_type: data['event_type'].presence || 'order.updated',
              event_at: parse_time(data['event_at'] || data['occurred_at'] || order_payload['updated_at']) || Time.current,
              payload_raw: data,
              processing_status: 'received'
            )

            Result.new(event: event, order: order, replay: false)
          end
        rescue ActiveRecord::RecordNotUnique
          existing = ExternalOrderEvent.find_by(source: source, source_event_id: source_event_id)
          Result.new(event: existing, order: existing&.external_order, replay: true)
        end

        private

        def upsert_order(source:, order_payload:, external_order_id:, payload:)
          external_number = order_payload['number'] || order_payload['order_number'] || order_payload['key']
          status = order_payload['status'].presence || 'received'
          payment_status = order_payload['payment_status'] || order_payload['financial_status']
          total_minor = normalize_money_minor(order_payload['total_price_minor'] || order_payload['total_price'] || order_payload['total_price_with_discount'])
          currency = order_payload['currency'] || order_payload['currency_code'] || 'RUB'
          event_time = parse_time(order_payload['updated_at']) || parse_time(order_payload['created_at']) || Time.current

          order = ExternalOrder.find_or_initialize_by(source: source, external_order_id: external_order_id.to_s)
          order.assign_attributes(
            external_order_number: external_number,
            status: status,
            payment_status: payment_status,
            total_minor: total_minor,
            currency: currency,
            payload_raw: payload,
            last_event_at: event_time
          )
          order.save!
          order
        end

        def replace_items!(order:, order_payload:)
          lines = Array(order_payload['order_lines'] || order_payload['lines'] || order_payload['items'])

          order.external_order_items.delete_all
          lines.each do |line|
            item = line.to_h.deep_stringify_keys
            sku = item['sku'] || item.dig('variant', 'sku') || item.dig('product', 'sku')
            next if sku.blank?

            qty = normalize_quantity(item['quantity'] || item['count'] || 1)
            unit_minor = normalize_money_minor(item['price_minor'] || item['sale_price'] || item['price'])
            product = Product.find_by(sku: sku.to_s)

            order.external_order_items.create!(
              sku: sku.to_s.strip,
              quantity: qty,
              unit_price_minor: unit_minor,
              currency: item['currency'] || order.currency || 'RUB',
              product: product,
              meta: item
            )
          end
        end

        def extract_source_event_id(data)
          data['source_event_id'] || data['event_id'] || data['id'] || data['requestId']
        end

        def extract_order_payload(data)
          (data['order'].is_a?(Hash) ? data['order'] : data).to_h.deep_stringify_keys
        end

        def extract_external_order_id(order_payload)
          order_payload['id'] || order_payload['external_id'] || order_payload['order_id']
        end

        def parse_time(value)
          return nil if value.blank?

          Time.iso8601(value.to_s)
        rescue StandardError
          nil
        end

        def normalize_quantity(value)
          BigDecimal(value.to_s.presence || '0')
        rescue StandardError
          BigDecimal('0')
        end

        def normalize_money_minor(value)
          return nil if value.nil?

          raw = value.to_s.tr(',', '.')
          return nil if raw.blank?

          decimal = BigDecimal(raw)
          if decimal.frac.zero? && decimal.abs >= 1000
            decimal.to_i
          else
            (decimal * 100).round.to_i
          end
        rescue StandardError
          nil
        end
      end
    end
  end
end
