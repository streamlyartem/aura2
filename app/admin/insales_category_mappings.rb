# frozen_string_literal: true

ActiveAdmin.register InsalesCategoryMapping do
  menu label: 'InSales Category Mappings', priority: 7

  permit_params :product_type, :tone, :length, :ombre, :structure, :insales_category_id, :aura_key, :aura_key_type,
                :insales_collection_title, :comment, :is_active

  filter :product_type
  filter :tone
  filter :length
  filter :ombre
  filter :structure
  filter :insales_category_id
  filter :aura_key
  filter :aura_key_type
  filter :is_active

  index do
    selectable_column
    id_column
    column :is_active
    column :aura_key_type
    column :aura_key
    column :product_type
    column :tone
    column :length
    column :ombre
    column :structure
    column :insales_category_id
    column :insales_collection_title
    column :comment
    column :updated_at
    actions
  end

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)
    f.inputs 'Mapping' do
      f.input :is_active
      f.input :aura_key_type, as: :select, collection: %w[path], include_blank: true
      f.input :aura_key, hint: 'Например: Срезы/Светлый/55'
      f.input :insales_collection_title
      f.input :comment
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
