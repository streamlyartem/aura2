# frozen_string_literal: true

module Pricing
  class SyncVariantPrices
    PRICE_CODES = {
      'retail' => :retail_price_per_g_cents,
      'small_wholesale' => :small_wholesale_price_per_g_cents,
      'big_wholesale' => :big_wholesale_price_per_g_cents,
      'wholesale_500_plus' => :wholesale_500_plus_price_per_g_cents
    }.freeze

    def self.call(product:, ms_product:)
      new.call(product: product, ms_product: ms_product)
    end

    def call(product:, ms_product:)
      PRICE_CODES.each do |code, attribute|
        cents = ms_product.public_send(attribute)
        next if cents.nil?

        price_type = PriceType.find_or_create_by!(code: code) do |item|
          item.currency = 'RUB'
        end

        VariantPrice.upsert(
          {
            variant_id: product.id,
            price_type_id: price_type.id,
            price_per_g_cents: cents.to_i,
            price_per_piece_cents: nil,
            created_at: Time.current,
            updated_at: Time.current
          },
          unique_by: :index_variant_prices_on_variant_id_and_price_type_id
        )
      end
    end
  end
end
