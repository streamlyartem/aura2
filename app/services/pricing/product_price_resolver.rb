# frozen_string_literal: true

module Pricing
  class ProductPriceResolver
    Result = Struct.new(:tier, :unit_price, :quantity, :total_price, keyword_init: true)

    TIER_RETAIL = 'retail'
    TIER_SMALL_WHOLESALE = 'small_wholesale'
    TIER_LARGE_WHOLESALE = 'large_wholesale'

    def call(product:, quantity_g:)
      quantity = quantity_g.to_f
      tier = resolve_tier(product, quantity)
      unit_price = resolve_price_for_tier(product, tier)

      Result.new(
        tier: tier,
        unit_price: unit_price,
        quantity: quantity,
        total_price: unit_price.to_f * quantity
      )
    end

    private

    def resolve_tier(product, quantity)
      return TIER_RETAIL unless srezy?(product)
      return TIER_LARGE_WHOLESALE if quantity >= 1000
      return TIER_SMALL_WHOLESALE if quantity >= 500

      TIER_RETAIL
    end

    def resolve_price_for_tier(product, tier)
      case tier
      when TIER_SMALL_WHOLESALE
        product.small_wholesale_price.presence || product.retail_price
      when TIER_LARGE_WHOLESALE
        product.large_wholesale_price.presence || product.small_wholesale_price.presence || product.retail_price
      else
        product.retail_price
      end.to_f
    end

    def srezy?(product)
      product.path_name.to_s.split('/').first.to_s.casecmp('Срезы').zero?
    end
  end
end
