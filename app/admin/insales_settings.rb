# frozen_string_literal: true

ActiveAdmin.register InsalesSetting do
  menu label: 'InSales Settings', priority: 5

  actions :index, :new, :create, :edit, :update

  permit_params :base_url, :login, :password, :category_id, :default_collection_id, :image_url_mode,
                :skip_products_without_sku, :skip_products_with_nonpositive_stock,
                allowed_store_names: []

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

  member_action :refresh_store_names, method: :post do
    setting = InsalesSetting.find(params[:id])
    begin
      store_names = MoyskladClient.new.store_names
    rescue StandardError => e
      Rails.logger.warn "[InSalesSettings] Refresh Moysklad stores failed: #{e.class} - #{e.message}"
      store_names = []
    end

    store_names = (store_names + ProductStock.distinct.order(:store_name).pluck(:store_name)).uniq
    setting.update!(
      cached_store_names: store_names,
      cached_store_names_synced_at: Time.zone.now
    )

    redirect_to edit_admin_insales_setting_path(setting), notice: 'Список складов обновлен.'
  end

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)

    store_names = f.object.cached_store_names_list
    store_names = (store_names + ProductStock.distinct.order(:store_name).pluck(:store_name)).uniq

    f.inputs 'InSales Settings' do
      f.input :base_url
      f.input :login
      f.input :password, as: :password
      f.input :category_id
      f.input :default_collection_id
      f.input :image_url_mode, as: :select, collection: %w[service_url rails_url], include_blank: false
      f.input :skip_products_without_sku, as: :boolean, label: 'Не загружать товары без артикула'
      f.input :skip_products_with_nonpositive_stock, as: :boolean,
                                                      label: 'Не загружать товары с нулевым остатком (ноль и меньше нуля)'
      f.input :allowed_store_names,
              as: :select,
              collection: store_names,
              label: 'Подключенные склады на продажу',
              input_html: {
                multiple: true,
                class: 'store-names-multiselect',
                size: [store_names.size, 10].min,
                data: { chips_target: 'insales-allowed-store-names-chips' }
              },
              hint: 'Выберите склады из списка. Выбранные склады отображаются ниже как теги. Если пусто — используется "Тест".'
      para '', id: 'insales-allowed-store-names-chips', class: 'insales-store-chips'
    end

    f.template.concat(
      f.template.javascript_tag(<<~JS)
        (() => {
          const initStoreChips = () => {
            document.querySelectorAll('select.store-names-multiselect').forEach((select) => {
              if (select.dataset.chipsInitialized === '1') return;

              const targetId = select.dataset.chipsTarget;
              if (!targetId) return;

              const chipsContainer = document.getElementById(targetId);
              if (!chipsContainer) return;

              const render = () => {
                const selected = Array.from(select.selectedOptions).map((option) => option.textContent.trim()).filter(Boolean);
                chipsContainer.innerHTML = '';

                if (selected.length === 0) {
                  const empty = document.createElement('span');
                  empty.className = 'insales-store-chip-empty';
                  empty.textContent = 'Склады не выбраны';
                  chipsContainer.appendChild(empty);
                  return;
                }

                selected.forEach((name) => {
                  const chip = document.createElement('span');
                  chip.className = 'insales-store-chip';
                  chip.textContent = name;
                  chipsContainer.appendChild(chip);
                });
              };

              select.addEventListener('change', render);
              select.dataset.chipsInitialized = '1';
              render();
            });
          };

          document.addEventListener('turbo:load', initStoreChips);
          document.addEventListener('DOMContentLoaded', initStoreChips);
        })();
      JS
    )

    f.template.concat(
      f.template.content_tag(
        :style,
        <<~CSS.html_safe
          .insales-store-chips {
            margin-top: 8px;
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
          }

          .insales-store-chip {
            display: inline-flex;
            align-items: center;
            padding: 4px 10px;
            border-radius: 999px;
            background: #eef2ff;
            color: #1f2937;
            font-size: 12px;
            line-height: 1.2;
            border: 1px solid #c7d2fe;
          }

          .insales-store-chip-empty {
            color: #6b7280;
            font-size: 12px;
          }
        CSS
      )
    )

    f.actions
  end

  action_item :refresh_store_names, only: :edit do
    link_to 'Обновить склады', refresh_store_names_admin_insales_setting_path(resource), method: :post
  end
end
