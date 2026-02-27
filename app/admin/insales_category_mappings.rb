# frozen_string_literal: true

ActiveAdmin.register InsalesCategoryMapping do
  menu parent: 'InSales', label: 'InSales Category Mappings', priority: 4,
       if: proc { current_admin_user&.can_access_admin_path?('/admin/insales_category_mappings') }

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

  scope :all, default: true
  scope('Path mappings') { |scope| scope.where(aura_key_type: 'path') }
  scope('Attribute mappings') { |scope| scope.where.not(aura_key_type: 'path') }

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
    column('InSales Collection ID', :insales_category_id)
    column :insales_collection_title
    column :comment
    column :updated_at
    actions
  end

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)
    f.inputs 'Mapping' do
      f.input :is_active
      f.input :aura_key_type, as: :select, collection: %w[path], include_blank: true, hint: 'Для маппинга по пути'
      f.input :aura_key, hint: 'Например: Срезы/Светлый/55 (без Каталог)'
      f.input :insales_collection_title
      f.input :comment
      f.input :insales_category_id, label: 'InSales Collection ID'
    end
    f.inputs 'Attribute Mapping (fallback)' do
      f.input :product_type
      f.input :tone
      f.input :length
      f.input :ombre, as: :select, collection: [['Any', nil], ['Yes', true], ['No', false]]
      f.input :structure
    end
    f.actions
  end
end
