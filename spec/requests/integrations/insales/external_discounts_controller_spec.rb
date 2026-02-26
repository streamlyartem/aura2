# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Integrations::Insales::ExternalDiscounts', type: :request do
  around do |example|
    previous = ENV['INSALES_EXTERNAL_DISCOUNT_TOKEN']
    ENV['INSALES_EXTERNAL_DISCOUNT_TOKEN'] = 'secret-token'
    example.run
    ENV['INSALES_EXTERNAL_DISCOUNT_TOKEN'] = previous
  end

  let!(:retail_type) { PriceType.create!(code: 'retail', currency: 'RUB') }
  let!(:small_type) { PriceType.create!(code: 'small_wholesale', currency: 'RUB') }
  let!(:ruleset) { PricingRuleset.create!(channel: 'insales', name: 'InSales tiers', is_active: true) }

  before do
    PricingTier.create!(pricing_ruleset: ruleset, min_eligible_weight_g: 0, max_eligible_weight_g: 499, price_type_code: 'retail', priority: 1)
    PricingTier.create!(pricing_ruleset: ruleset, min_eligible_weight_g: 500, max_eligible_weight_g: nil, price_type_code: 'small_wholesale', priority: 1)
  end

  it 'returns discount for valid token' do
    product = create(:product, unit_type: 'weight', unit_weight_g: 120)
    VariantPrice.create!(variant: product, price_type: retail_type, price_per_g_cents: 150)
    VariantPrice.create!(variant: product, price_type: small_type, price_per_g_cents: 120)

    InsalesProductMapping.create!(aura_product_id: product.id, insales_product_id: 123, insales_variant_id: 777)

    post '/integrations/insales/external_discount',
         params: {
           token: 'secret-token',
           items: [
             { variant_id: 777, quantity: 5, sale_price: '180.00' }
           ]
         }

    expect(response).to have_http_status(:ok)
    payload = JSON.parse(response.body)
    expect(payload['discount']).to eq(18_000)
    expect(payload['discount_type']).to eq('MONEY')
  end

  it 'returns 401 for invalid token' do
    post '/integrations/insales/external_discount', params: { token: 'wrong', items: [] }

    expect(response).to have_http_status(:unauthorized)
  end

  it 'never returns negative discount' do
    product = create(:product, unit_type: 'weight', unit_weight_g: 100)
    VariantPrice.create!(variant: product, price_type: retail_type, price_per_g_cents: 100)
    VariantPrice.create!(variant: product, price_type: small_type, price_per_g_cents: 80)

    InsalesProductMapping.create!(aura_product_id: product.id, insales_product_id: 123, insales_variant_id: 888)

    post '/integrations/insales/external_discount',
         params: {
           token: 'secret-token',
           items: [
             { variant_id: 888, quantity: 5, sale_price: '70.00' }
           ]
         }

    expect(response).to have_http_status(:ok)
    payload = JSON.parse(response.body)
    expect(payload['discount']).to eq(0)
  end
end
