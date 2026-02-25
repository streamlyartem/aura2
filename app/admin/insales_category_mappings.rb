# frozen_string_literal: true

ActiveAdmin.register InsalesCategoryMapping do
  menu label: 'InSales Category Mappings', priority: 7

  permit_params :product_type, :tone, :length, :ombre, :structure, :insales_category_id

  filter :product_type
  filter :tone
  filter :length
  filter :ombre
  filter :structure
  filter :insales_category_id

  index do
    selectable_column
    id_column
    column :product_type
    column :tone
    column :length
    column :ombre
    column :structure
    column :insales_category_id
    column :updated_at
    actions
  end

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)
    f.inputs 'Mapping' do
      f.input :product_type
      f.input :tone
      f.input :length
      f.input :ombre, as: :select, collection: [['Any', nil], ['Yes', true], ['No', false]]
      f.input :structure
      f.input :insales_category_id
    end
    f.actions
  end
end
