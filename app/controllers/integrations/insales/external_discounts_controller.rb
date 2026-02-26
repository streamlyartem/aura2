# frozen_string_literal: true

module Integrations
  module Insales
    class ExternalDiscountsController < ActionController::API
      before_action :authorize_request!

      def create
        cart_lines = extract_cart_lines
        current_total_cents = extract_current_total_cents
        pricing = Pricing::Engine.call(channel: 'insales', cart_lines: cart_lines)

        target_total_cents = pricing.total_cents.to_i
        discount_cents = [current_total_cents - target_total_cents, 0].max

        Rails.logger.info(
          "[InSales][ExternalDiscount] eligible_weight_g=#{pricing.eligible_weight_g} " \
          "tier=#{pricing.tier_price_type_code} current_total_cents=#{current_total_cents} " \
          "target_total_cents=#{target_total_cents} discount_cents=#{discount_cents} lines_count=#{pricing.lines.size}"
        )

        render json: {
          discount: discount_cents,
          discount_type: 'MONEY',
          title: 'Оптовая цена'
        }
      rescue StandardError => e
        Rails.logger.error("[InSales][ExternalDiscount] failed: #{e.class} #{e.message}")
        render json: { discount: 0, discount_type: 'MONEY', title: 'Оптовая цена' }
      end

      private

      def authorize_request!
        expected = ENV['INSALES_EXTERNAL_DISCOUNT_TOKEN'].to_s
        provided = params[:token].presence || request.headers['X-Insales-Token'].presence || bearer_token

        head :unauthorized if expected.blank? || provided.blank? || !ActiveSupport::SecurityUtils.secure_compare(provided.to_s, expected)
      end

      def bearer_token
        request.headers['Authorization'].to_s.delete_prefix('Bearer ').presence
      end

      def extract_cart_lines
        lines_payload.filter_map do |line|
          insales_variant_id = line[:variant_id] || line['variant_id'] || line[:id] || line['id']
          qty = (line[:quantity] || line['quantity'] || line[:qty] || line['qty']).to_i
          next if insales_variant_id.blank? || qty <= 0

          mapping = InsalesProductMapping.find_by(insales_variant_id: insales_variant_id)
          next unless mapping

          { variant_id: mapping.aura_product_id, qty: qty }
        end
      end

      def extract_current_total_cents
        lines_payload.sum do |line|
          qty = (line[:quantity] || line['quantity'] || line[:qty] || line['qty']).to_i
          next 0 if qty <= 0

          unit_price = line[:sale_price_cents] || line['sale_price_cents'] || line[:sale_price] || line['sale_price'] || line[:price] || line['price'] || 0
          normalize_price_to_cents(unit_price) * qty
        end
      end

      def normalize_price_to_cents(value)
        return value.to_i if value.is_a?(Integer)

        raw = value.to_s.tr(',', '.').strip
        return 0 if raw.blank?

        (BigDecimal(raw) * 100).round.to_i
      rescue ArgumentError
        0
      end

      def lines_payload
        @lines_payload ||= begin
          body = request.request_parameters.presence || {}
          body[:items] || body['items'] || body[:order_lines] || body['order_lines'] || []
        end
      end
    end
  end
end
