# frozen_string_literal: true

ActiveAdmin.register PriceType do
  menu label: 'Price Types', priority: 12

  permit_params :code, :ms_price_type_id, :currency

  filter :code
  filter :ms_price_type_id
  filter :currency

  index do
    selectable_column
    id_column
    column :code
    column :ms_price_type_id
    column :currency
    column :updated_at
    actions
  end

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)
    f.inputs do
      f.input :code
      f.input :ms_price_type_id
      f.input :currency
    end
    f.actions
  end
end
