# frozen_string_literal: true

ActiveAdmin.register PricingTier do
  menu label: 'Pricing Tiers', priority: 14

  permit_params :pricing_ruleset_id, :min_eligible_weight_g, :max_eligible_weight_g, :price_type_code, :priority

  filter :pricing_ruleset
  filter :price_type_code
  filter :min_eligible_weight_g
  filter :max_eligible_weight_g

  index do
    selectable_column
    id_column
    column :pricing_ruleset
    column :priority
    column :min_eligible_weight_g
    column :max_eligible_weight_g
    column :price_type_code
    column :updated_at
    actions
  end

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)
    f.inputs do
      f.input :pricing_ruleset
      f.input :priority
      f.input :min_eligible_weight_g
      f.input :max_eligible_weight_g
      f.input :price_type_code, as: :select, collection: PriceType.order(:code).pluck(:code)
    end
    f.actions
  end
end
