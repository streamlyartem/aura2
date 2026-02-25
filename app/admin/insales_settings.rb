# frozen_string_literal: true

ActiveAdmin.register InsalesSetting do
  menu label: 'InSales Settings', priority: 5

  actions :index, :new, :create, :edit, :update

  permit_params :base_url, :login, :password, :category_id, :default_collection_id, :image_url_mode, allowed_store_names: []

  controller do
    def index
      setting = InsalesSetting.first
      if setting
        redirect_to edit_admin_insales_setting_path(setting)
      else
        redirect_to new_admin_insales_setting_path
      end
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

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)

    store_names = begin
      MoyskladClient.new.stores_list.map { |store| store['name'].to_s }
    rescue StandardError => e
      Rails.logger.warn "[InSalesSettings] Fetch Moysklad stores failed: #{e.class} - #{e.message}"
      []
    end
    store_names = (store_names + ProductStock.distinct.order(:store_name).pluck(:store_name)).uniq

    f.inputs 'InSales Settings' do
      f.input :base_url
      f.input :login
      f.input :password, as: :password
      f.input :category_id
      f.input :default_collection_id
      f.input :image_url_mode, as: :select, collection: %w[service_url rails_url], include_blank: false
      f.input :allowed_store_names,
              as: :select,
              collection: store_names,
              input_html: { multiple: true },
              hint: 'Склады, которые участвуют в экспорте в InSales. Если пусто — используется "Тест".'
    end

    f.actions
  end
end
