# frozen_string_literal: true

ActiveAdmin.register AuraProductSource do
  menu label: 'Источники', parent: 'Товары AURA', priority: 3,
       if: proc { current_admin_user&.can_access_admin_path?('/admin/aura_product_sources') }

  permit_params :code, :name, :source_kind, :active, :priority, :authoritative, :settings

  config.sort_order = 'priority_asc'

  filter :code
  filter :name
  filter :source_kind
  filter :active

  index do
    selectable_column
    id_column
    column :priority
    column :code
    column :name
    column :source_kind
    column('Master') { |row| status_tag(row.authoritative? ? 'yes' : 'no') }
    column('Активен') { |row| status_tag(row.active? ? 'yes' : 'no') }
    actions
  end

  show do
    attributes_table do
      row :id
      row :priority
      row :code
      row :name
      row :source_kind
      row('Master') { |row| row.authoritative? ? 'Да' : 'Нет' }
      row('Активен') { |row| row.active? ? 'Да' : 'Нет' }
      row('Settings') { |row| pre JSON.pretty_generate(row.settings || {}) }
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.semantic_errors

    f.inputs 'Источник' do
      f.input :priority
      f.input :code
      f.input :name
      f.input :source_kind, as: :select, collection: [['moysklad', 'moysklad'], ['manual', 'manual'], ['other', 'other']]
      f.input :active
      f.input :authoritative, label: 'Источник master для товарных данных'
      f.input :settings, as: :text, input_html: { rows: 6 }, hint: 'JSON, например {"api_base":"..."}'
    end

    f.actions
  end
end
