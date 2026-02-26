# frozen_string_literal: true

ActiveAdmin.register PricingRuleset do
  menu label: 'Pricing Rulesets', priority: 13

  permit_params :channel, :name, :is_active

  filter :channel
  filter :name
  filter :is_active

  index do
    selectable_column
    id_column
    column :channel
    column :name
    column :is_active
    column :updated_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :channel
      row :name
      row :is_active
      row :created_at
      row :updated_at
    end

    panel 'Pricing tiers' do
      table_for resource.pricing_tiers.ordered do
        column :priority
        column :min_eligible_weight_g
        column :max_eligible_weight_g
        column :price_type_code
        column :updated_at
      end
    end
  end

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)
    f.inputs do
      f.input :channel
      f.input :name
      f.input :is_active
    end
    f.actions
  end
end
