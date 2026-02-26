# frozen_string_literal: true

ActiveAdmin.register MoyskladStore do
  menu label: 'Склады МС', parent: 'МойСклад', priority: 3

  actions :index, :edit, :update
  config.batch_actions = true
  config.filters = false

  permit_params :selected_for_import

  action_item :refresh, only: :index do
    link_to 'Обновить список', refresh_admin_moysklad_stores_path, method: :post
  end

  collection_action :refresh, method: :post do
    names = MoyskladStore.refresh_from_moysklad!
    redirect_to admin_moysklad_stores_path, notice: "Список складов обновлён: #{names.size}"
  rescue StandardError => e
    redirect_to admin_moysklad_stores_path, alert: "Не удалось обновить список складов: #{e.class} - #{e.message}"
  end

  member_action :toggle_selected, method: :post do
    resource.update!(selected_for_import: ActiveModel::Type::Boolean.new.cast(params[:selected]))
    redirect_to admin_moysklad_stores_path, notice: 'Выбор склада обновлён'
  end

  batch_action :select_for_import do |ids|
    batch_action_collection.find(ids).each { |store| store.update(selected_for_import: true) }
    redirect_to collection_path, notice: 'Склады отмечены для импорта'
  end

  batch_action :unselect_for_import do |ids|
    batch_action_collection.find(ids).each { |store| store.update(selected_for_import: false) }
    redirect_to collection_path, notice: 'Склады сняты с импорта'
  end

  index do
    selectable_column
    id_column
    column :name
    column 'Импортировать' do |store|
      form action: toggle_selected_admin_moysklad_store_path(store), method: :post, style: 'margin:0' do
        input type: 'hidden', name: 'authenticity_token', value: form_authenticity_token
        input type: 'hidden', name: 'selected', value: (!store.selected_for_import?).to_s
        input type: 'checkbox', checked: store.selected_for_import?, onchange: 'this.form.submit();'
      end
    end
    column :last_seen_at
    column :updated_at
    actions defaults: false do |store|
      item 'Редактировать', edit_admin_moysklad_store_path(store)
    end
  end

  form do |f|
    f.inputs do
      f.input :name, input_html: { disabled: true }
      f.input :selected_for_import, label: 'Использовать для импорта'
    end
    f.actions
  end
end
