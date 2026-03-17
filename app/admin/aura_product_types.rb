# frozen_string_literal: true

ActiveAdmin.register AuraProductType do
  menu label: 'Типы товаров', parent: 'Товары AURA', priority: 2,
       if: proc { current_admin_user&.can_access_admin_path?('/admin/aura_product_types') }

  permit_params :code, :name, :description, :matcher_path_prefix, :matcher_unit_type,
                :weight_from_stock, :active, :priority

  config.sort_order = 'priority_asc'

  filter :code
  filter :name
  filter :active
  filter :matcher_unit_type

  index do
    selectable_column
    id_column
    column :priority
    column :code
    column :name
    column('Path префикс', &:matcher_path_prefix)
    column('Unit type', &:matcher_unit_type)
    column('Weight = Stock') { |row| status_tag(row.weight_from_stock? ? 'yes' : 'no') }
    column('Активен') { |row| status_tag(row.active? ? 'yes' : 'no') }
    actions
  end

  show do
    attributes_table do
      row :id
      row :priority
      row :code
      row :name
      row :description
      row('Path префикс') { |row| row.matcher_path_prefix.presence || '—' }
      row('Unit type') { |row| row.matcher_unit_type.presence || '—' }
      row('Weight = Stock') { |row| row.weight_from_stock? ? 'Да' : 'Нет' }
      row('Активен') { |row| row.active? ? 'Да' : 'Нет' }
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.semantic_errors

    f.inputs 'Тип товара' do
      f.input :priority
      f.input :code
      f.input :name
      f.input :description
      f.input :active
    end

    f.inputs 'Правила определения' do
      f.input :matcher_path_prefix, hint: 'Пример: Срезы/Светлый'
      f.input :matcher_unit_type, as: :select, collection: [['Любой', ''], ['weight', 'weight'], ['piece', 'piece']]
    end

    f.inputs 'Поведение' do
      f.input :weight_from_stock, label: 'Для этого типа брать Weight из текущего Stock'
    end

    f.actions
  end
end
