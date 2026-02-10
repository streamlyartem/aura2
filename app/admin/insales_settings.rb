# frozen_string_literal: true

ActiveAdmin.register InsalesSetting do
  menu label: 'InSales Settings', priority: 5

  actions :index, :new, :create, :edit, :update

  permit_params :base_url, :login, :password, :category_id, :default_collection_id, :image_url_mode

  controller do
    def index
      super
    end

    def new
      if InsalesSetting.exists?
        redirect_to edit_admin_insales_setting_path(InsalesSetting.first)
      else
        super
      end
    end

    def create
      if InsalesSetting.exists?
        redirect_to edit_admin_insales_setting_path(InsalesSetting.first),
                    alert: 'InSales settings already exist.'
      else
        super
      end
    end
  end

  collection_action :sync_now, method: :post do
    store_name = params[:store_name].presence || 'Тест'
    Insales::SyncProductStocksJob.perform_later(store_name: store_name)
    redirect_to admin_insales_settings_path(store_name: store_name),
                notice: "Запущена синхронизация склада #{store_name}"
  end

  action_item :edit_settings, only: :index do
    setting = InsalesSetting.first
    if setting
      link_to 'Редактировать настройки', edit_admin_insales_setting_path(setting)
    else
      link_to 'Создать настройки', new_admin_insales_setting_path
    end
  end

  index title: 'InSales Settings' do
    store_names = ProductStock.distinct.order(:store_name).pluck(:store_name)
    preferred_store = params[:store_name].presence || 'Тест'
    store_name = store_names.include?(preferred_store) ? preferred_store : (store_names.first || 'Тест')

    stock_scope = ProductStock.where(store_name: store_name)
    products_with_stock = stock_scope.select(:product_id).distinct.count
    total_stocks = stock_scope.count

    products_with_insales_mapping = InsalesProductMapping.count
    images_with_insales_mapping = InsalesImageMapping.count
    settings = InsalesSetting.first
    state = InsalesStockSyncState.find_by(store_name: store_name)

    panel 'Синхронизация остатков (InSales)' do
      div class: 'mb-4' do
        form action: url_for(action: :sync_now), method: :post do
          input type: 'hidden', name: 'authenticity_token', value: form_authenticity_token
          label 'Склад'
          select name: 'store_name' do
            store_names.each do |name|
              option name, value: name, selected: name == store_name
            end
          end
          div class: 'mt-3' do
            input type: 'submit', value: 'Синхронизировать', class: 'button'
          end
        end
      end

      table_for [
        ['InSales Base URL', settings&.base_url || '—'],
        ['InSales Category ID', settings&.category_id || '—'],
        ['InSales Collection ID', settings&.default_collection_id || '—'],
        ['Last stock sync', state&.last_stock_sync_at || '—'],
        ['Last sync run', state&.last_run_at || '—'],
        ['Status', state&.last_status || '—']
      ] do
        column('Metric') { |row| row[0] }
        column('Value') { |row| row[1] }
      end
    end

    panel 'Статус последней синхронизации' do
      table_for [
        ['Status', state&.last_status || '—'],
        ['Processed', state&.processed || '—'],
        ['Created', state&.created || '—'],
        ['Updated', state&.updated || '—'],
        ['Errors', state&.error_count || '—'],
        ['Variants updated', state&.variants_updated || '—'],
        ['Last error', state&.last_status == 'failed' ? (state.last_error.presence || '—') : '—'],
        ['Products with stock records', products_with_stock],
        ['Stock rows', total_stocks],
        ['Products mapped to InSales', products_with_insales_mapping],
        ['Images mapped to InSales', images_with_insales_mapping]
      ] do
        column('Metric') { |row| row[0] }
        column('Value') { |row| row[1] }
      end
    end
  end

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)

    f.inputs 'InSales Settings' do
      f.input :base_url
      f.input :login
      f.input :password, as: :password
      f.input :category_id
      f.input :default_collection_id
      f.input :image_url_mode, as: :select, collection: %w[service_url rails_url], include_blank: false
    end

    f.actions
  end
end
