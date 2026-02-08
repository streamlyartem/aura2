# frozen_string_literal: true

ActiveAdmin.register_page 'Insales Sync' do
  menu priority: 5, label: 'InSales Sync'

  content title: 'InSales Sync' do
    store_name = defined?(MoyskladClient::TEST_STORE_NAME) ? MoyskladClient::TEST_STORE_NAME : 'Тест'

    stock_scope = ProductStock.where(store_name: store_name)
    last_stock_sync_at = stock_scope.maximum(:synced_at)

    products_with_stock = stock_scope.select(:product_id).distinct.count
    total_stocks = stock_scope.count

    products_with_insales_mapping = InsalesProductMapping.count
    images_with_insales_mapping = InsalesImageMapping.count
    settings = InsalesSetting.first

    status = Rails.cache.read("insales_sync_status:#{store_name}")

    panel "Test store sync status (#{store_name})" do
      div do
        form action: sync_now_admin_insales_sync_path, method: :post do
          input type: 'hidden', name: 'store_name', value: store_name
          input type: 'hidden', name: 'collection_id', value: settings&.default_collection_id
          input type: 'hidden', name: 'update_product_fields', value: 'true'
          input type: 'hidden', name: 'sync_images', value: 'false'
          input type: 'hidden', name: 'authenticity_token', value: form_authenticity_token
          input type: 'submit', value: 'Sync now', class: 'button'
        end
      end

      table_for [
        ['Last stock sync', last_stock_sync_at || '—'],
        ['Products with stock records', products_with_stock],
        ['Stock rows', total_stocks],
        ['Products mapped to InSales', products_with_insales_mapping],
        ['Images mapped to InSales', images_with_insales_mapping],
        ['Last InSales sync', status&.dig(:updated_at)&.to_s || '—'],
        ['Processed', status&.dig(:processed) || '—'],
        ['Created', status&.dig(:created) || '—'],
        ['Updated', status&.dig(:updated) || '—'],
        ['Errors', status&.dig(:errors) || '—'],
        ['Variants updated', status&.dig(:variant_updates) || '—']
      ] do
        column('Metric') { |row| row[0] }
        column('Value') { |row| row[1] }
      end
    end
  end

  page_action :sync_now, method: :post do
    store_name = params[:store_name].presence || 'Тест'
    collection_id = params[:collection_id].presence
    update_product_fields = params[:update_product_fields].to_s == 'true'
    sync_images = params[:sync_images].to_s == 'true'

    Insales::SyncStoreJob.perform_later(
      store_name: store_name,
      collection_id: collection_id,
      update_product_fields: update_product_fields,
      sync_images: sync_images
    )

    redirect_to admin_insales_sync_path, notice: 'InSales sync job enqueued.'
  end
end
