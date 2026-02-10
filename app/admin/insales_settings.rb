# frozen_string_literal: true

ActiveAdmin.register InsalesSetting do
  menu label: 'InSales Settings', priority: 5

  actions :index, :new, :create, :edit, :update

  permit_params :base_url, :login, :password, :category_id, :default_collection_id, :image_url_mode

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
