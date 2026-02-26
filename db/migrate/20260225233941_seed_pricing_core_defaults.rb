class SeedPricingCoreDefaults < ActiveRecord::Migration[8.0]
  def change
    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE products
          SET unit_weight_g = COALESCE(unit_weight_g, weight),
              ms_stock_g = COALESCE(ms_stock_g, FLOOR(COALESCE(weight, 0))::integer)
        SQL

        price_type_model = Class.new(ActiveRecord::Base) do
          self.table_name = 'price_types'
        end
        ruleset_model = Class.new(ActiveRecord::Base) do
          self.table_name = 'pricing_rulesets'
        end
        tier_model = Class.new(ActiveRecord::Base) do
          self.table_name = 'pricing_tiers'
        end

        codes = %w[retail small_wholesale big_wholesale wholesale_500_plus]
        codes.each do |code|
          price_type_model.find_or_create_by!(code: code) do |price_type|
            price_type.currency = 'RUB'
          end
        end

        ruleset = ruleset_model.find_or_create_by!(channel: 'insales', name: 'InSales default') do |item|
          item.is_active = true
        end

        tier_model.find_or_create_by!(
          pricing_ruleset_id: ruleset.id,
          min_eligible_weight_g: 0,
          max_eligible_weight_g: nil,
          price_type_code: 'retail',
          priority: 0
        )
      end
    end
  end
end
