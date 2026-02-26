# frozen_string_literal: true

ActiveAdmin.register InsalesCatalogItem do
  menu parent: 'InSales', label: 'Каталог InSales', priority: 1

  actions :index, :show
  includes :product
  config.filters = false

  scope :ready, default: true
  scope :error

  action_item :prepare_catalog, only: :index do
    link_to 'Пересчитать каталог', prepare_catalog_admin_insales_catalog_items_path, method: :post
  end

  collection_action :prepare_catalog, method: :post do
    Insales::Catalog::PrepareJob.perform_later
    redirect_to admin_insales_catalog_items_path, notice: 'Пересчет каталога запущен'
  end

  index title: 'Каталог InSales' do
    id_column
    column('Товар') do |item|
      next item.product_id unless item.product

      link_to item.product.name.presence || item.product_id, admin_product_path(item.product)
    end
    column('SKU') { |item| item.product&.sku.presence || item.product&.code || '—' }
    column('Тип') { |item| item.product&.unit_type || '—' }
    column('Вес (г)') { |item| item.product&.weight || '—' }
    column('Qty на витрине', :export_quantity)
    column('Retail') { |item| human_price(item.prices_cents&.dig('retail')) }
    column('Small Wholesale') { |item| human_price(item.prices_cents&.dig('small_wholesale')) }
    column('Big Wholesale') { |item| human_price(item.prices_cents&.dig('big_wholesale')) }
    column('500+ Wholesale') { |item| human_price(item.prices_cents&.dig('wholesale_500_plus')) }
    column :status
    column :skip_reason
    column :prepared_at
    actions
  end

  show title: proc { |item| "Каталог InSales: #{item.product&.name || item.product_id}" } do
    attributes_table do
      row :id
      row('Товар') { |item| item.product ? link_to(item.product.name, admin_product_path(item.product)) : item.product_id }
      row('SKU') { |item| item.product&.sku.presence || item.product&.code || '—' }
      row('Тип') { |item| item.product&.unit_type || '—' }
      row('Вес (г)') { |item| item.product&.weight || '—' }
      row('Qty на витрине', &:export_quantity)
      row :status
      row :skip_reason
      row('Retail') { |item| human_price(item.prices_cents&.dig('retail')) }
      row('Small Wholesale') { |item| human_price(item.prices_cents&.dig('small_wholesale')) }
      row('Big Wholesale') { |item| human_price(item.prices_cents&.dig('big_wholesale')) }
      row('500+ Wholesale') { |item| human_price(item.prices_cents&.dig('wholesale_500_plus')) }
      row :prepared_at
      row :last_error
    end

    panel 'Сырьевые данные товара' do
      product = resource.product
      if product.nil?
        div 'Товар не найден'
      else
        attributes_table_for product do
          row :retail_price
          row :small_wholesale_price
          row :large_wholesale_price
          row :five_hundred_plus_wholesale_price
          row :weight
          row :unit_type
        end
      end
    end

    panel 'Остатки по подключенным складам' do
      stores = selected_store_names
      stock_rows = ProductStock.where(product_id: resource.product_id, store_name: stores).order(:store_name)
      if stock_rows.none?
        div 'Нет остатков по выбранным складам'
      else
        table_for stock_rows do
          column :store_name
          column :stock
          column :free_stock
          column :reserve
          column :synced_at
        end
      end
    end
  end

  controller do
    helper_method :human_price

    def human_price(cents)
      return '—' if cents.blank?

      value = cents.to_d / 100
      format('%.2f ₽', value)
    end

    def selected_store_names
      names = InsalesSetting.first&.allowed_store_names_list
      names = [MoyskladClient::TEST_STORE_NAME] if names.blank?
      names
    end
  end
end
