# frozen_string_literal: true

module Pricing
  class Engine
    LineResult = Struct.new(
      :variant_id,
      :qty,
      :unit_type,
      :unit_weight_g,
      :line_weight_g,
      :unit_price_cents,
      :line_total_cents,
      keyword_init: true
    )

    Result = Struct.new(:tier_price_type_code, :eligible_weight_g, :lines, :total_cents, keyword_init: true)

    DEFAULT_PRICE_TYPE = 'retail'

    def self.call(channel:, cart_lines:)
      new(channel: channel, cart_lines: cart_lines).call
    end

    def initialize(channel:, cart_lines:)
      @channel = channel.to_s
      @cart_lines = Array(cart_lines)
    end

    def call
      prepared_lines = normalize_lines
      variants = Product.where(id: prepared_lines.map { |line| line[:variant_id] }).index_by(&:id)
      prices = load_prices(prepared_lines.map { |line| line[:variant_id] })

      eligible_weight_g = prepared_lines.sum do |line|
        variant = variants[line[:variant_id]]
        next 0 unless variant&.unit_type == 'weight'

        validate_weight_data!(variant)
        variant.unit_weight_g.to_d * line[:qty]
      end

      price_type_code = resolve_price_type_code(eligible_weight_g.to_i)
      line_results = prepared_lines.map { |line| build_line_result(line, variants, prices, price_type_code) }
      total_cents = line_results.sum(&:line_total_cents)

      Result.new(
        tier_price_type_code: price_type_code,
        eligible_weight_g: eligible_weight_g,
        lines: line_results,
        total_cents: total_cents
      )
    end

    private

    attr_reader :channel, :cart_lines

    def normalize_lines
      cart_lines.filter_map do |line|
        variant_id = line[:variant_id] || line['variant_id']
        qty = (line[:qty] || line['qty'] || line[:quantity] || line['quantity']).to_i
        next if variant_id.blank? || qty <= 0

        { variant_id: variant_id, qty: qty }
      end
    end

    def resolve_price_type_code(eligible_weight_g)
      ruleset = PricingRuleset.active.find_by(channel: channel)
      return DEFAULT_PRICE_TYPE unless ruleset

      tier = ruleset.pricing_tiers.ordered.find { |item| item.matches_weight?(eligible_weight_g) }
      tier&.price_type_code.presence || DEFAULT_PRICE_TYPE
    end

    def build_line_result(line, variants, prices, price_type_code)
      variant = variants[line[:variant_id]]
      raise ActiveRecord::RecordNotFound, "Variant not found: #{line[:variant_id]}" unless variant

      if variant.unit_type == 'weight'
        build_weight_line_result(line, variant, prices, price_type_code)
      else
        build_piece_line_result(line, variant, prices, price_type_code)
      end
    end

    def build_weight_line_result(line, variant, prices, price_type_code)
      validate_weight_data!(variant)

      unit_weight_g = variant.unit_weight_g.to_d
      line_weight_g = unit_weight_g * line[:qty]
      price_per_g_cents = price_for_type(prices, variant, price_type_code, :price_per_g_cents)
      unit_price_cents = (price_per_g_cents * unit_weight_g).round
      line_total_cents = unit_price_cents * line[:qty]

      LineResult.new(
        variant_id: variant.id,
        qty: line[:qty],
        unit_type: variant.unit_type,
        unit_weight_g: unit_weight_g,
        line_weight_g: line_weight_g,
        unit_price_cents: unit_price_cents,
        line_total_cents: line_total_cents
      )
    end

    def build_piece_line_result(line, variant, prices, price_type_code)
      unit_price_cents = price_for_type(prices, variant, price_type_code, :price_per_piece_cents)
      line_total_cents = unit_price_cents * line[:qty]

      LineResult.new(
        variant_id: variant.id,
        qty: line[:qty],
        unit_type: variant.unit_type,
        unit_weight_g: nil,
        line_weight_g: 0,
        unit_price_cents: unit_price_cents,
        line_total_cents: line_total_cents
      )
    end

    def validate_weight_data!(variant)
      return if variant.unit_weight_g.present? && variant.unit_weight_g.to_d.positive?

      raise Pricing::Errors::InvalidWeightData, "Variant #{variant.id} has invalid unit_weight_g"
    end

    def load_prices(variant_ids)
      rows = VariantPrice.includes(:price_type).where(variant_id: variant_ids)
      rows.group_by(&:variant_id).transform_values do |variant_rows|
        variant_rows.each_with_object({}) do |row, memo|
          memo[row.price_type.code] = row
        end
      end
    end

    def price_for_type(prices, variant, price_type_code, attribute)
      desired = prices.dig(variant.id, price_type_code)&.public_send(attribute)
      return desired.to_i if desired.present?

      fallback = prices.dig(variant.id, DEFAULT_PRICE_TYPE)&.public_send(attribute)
      return fallback.to_i if fallback.present?

      if attribute == :price_per_piece_cents
        decimal_to_cents(variant.retail_price)
      else
        retail_cents = decimal_to_cents(variant.retail_price)
        unit_weight = variant.unit_weight_g.to_d
        return 0 if unit_weight <= 0

        (retail_cents / unit_weight).round
      end
    end

    def decimal_to_cents(value)
      (value.to_d * 100).round
    end
  end
end
