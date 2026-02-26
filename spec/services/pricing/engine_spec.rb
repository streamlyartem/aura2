# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pricing::Engine do
  let!(:retail_type) { PriceType.create!(code: 'retail', currency: 'RUB') }
  let!(:small_type) { PriceType.create!(code: 'small_wholesale', currency: 'RUB') }
  let!(:big_type) { PriceType.create!(code: 'big_wholesale', currency: 'RUB') }

  let!(:ruleset) { PricingRuleset.create!(channel: 'insales', name: 'InSales tiers', is_active: true) }

  before do
    PricingTier.create!(pricing_ruleset: ruleset, min_eligible_weight_g: 0, max_eligible_weight_g: 499, price_type_code: 'retail', priority: 1)
    PricingTier.create!(pricing_ruleset: ruleset, min_eligible_weight_g: 500, max_eligible_weight_g: 999, price_type_code: 'small_wholesale', priority: 1)
    PricingTier.create!(pricing_ruleset: ruleset, min_eligible_weight_g: 1000, max_eligible_weight_g: nil, price_type_code: 'big_wholesale', priority: 1)
  end

  it 'calculates weight-only cart and chooses wholesale tier by total grams' do
    variant = create(:product, unit_type: 'weight', unit_weight_g: 120, retail_price: 0)
    VariantPrice.create!(variant: variant, price_type: retail_type, price_per_g_cents: 150)
    VariantPrice.create!(variant: variant, price_type: small_type, price_per_g_cents: 120)

    result = described_class.call(channel: 'insales', cart_lines: [{ variant_id: variant.id, qty: 5 }])

    expect(result.eligible_weight_g.to_i).to eq(600)
    expect(result.tier_price_type_code).to eq('small_wholesale')
    expect(result.lines.first.unit_price_cents).to eq(14_400)
    expect(result.total_cents).to eq(72_000)
  end

  it 'counts eligible weight only for weight variants in mixed cart' do
    weight_variant = create(:product, unit_type: 'weight', unit_weight_g: 100, retail_price: 0)
    piece_variant = create(:product, unit_type: 'piece', unit_weight_g: nil, retail_price: 250)

    VariantPrice.create!(variant: weight_variant, price_type: retail_type, price_per_g_cents: 100)
    VariantPrice.create!(variant: weight_variant, price_type: small_type, price_per_g_cents: 80)
    VariantPrice.create!(variant: piece_variant, price_type: retail_type, price_per_piece_cents: 25_000)

    result = described_class.call(
      channel: 'insales',
      cart_lines: [
        { variant_id: weight_variant.id, qty: 2 },
        { variant_id: piece_variant.id, qty: 3 }
      ]
    )

    expect(result.eligible_weight_g.to_i).to eq(200)
    expect(result.tier_price_type_code).to eq('retail')
    expect(result.total_cents).to eq(95_000)
  end

  it 'treats tier boundaries as inclusive' do
    variant = create(:product, unit_type: 'weight', unit_weight_g: 100, retail_price: 0)
    VariantPrice.create!(variant: variant, price_type: retail_type, price_per_g_cents: 100)
    VariantPrice.create!(variant: variant, price_type: small_type, price_per_g_cents: 80)
    VariantPrice.create!(variant: variant, price_type: big_type, price_per_g_cents: 70)

    at_500 = described_class.call(channel: 'insales', cart_lines: [{ variant_id: variant.id, qty: 5 }])
    at_1000 = described_class.call(channel: 'insales', cart_lines: [{ variant_id: variant.id, qty: 10 }])

    expect(at_500.tier_price_type_code).to eq('small_wholesale')
    expect(at_1000.tier_price_type_code).to eq('big_wholesale')
  end
end
