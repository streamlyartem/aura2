# frozen_string_literal: true

ActiveAdmin.register_page 'Insales Sync' do
  menu priority: 5, label: 'InSales Sync'

  page_action :sync_now, method: :post do
    store_name = params[:store_name].presence || 'Тест'

    Insales::SyncProductStocksJob.perform_later(store_name: store_name)

    redirect_to admin_insales_sync_path, notice: 'Синхронизация запущена'
  end

  action_item :sync_now, only: :index do
    link_to 'Sync now', url_for(action: :sync_now), method: :post
  end

  content title: 'InSales Sync' do
    store_name = defined?(MoyskladClient::TEST_STORE_NAME) ? MoyskladClient::TEST_STORE_NAME : 'Тест'

    stock_scope = ProductStock.where(store_name: store_name)
    last_stock_sync_at = stock_scope.maximum(:synced_at)

    products_with_stock = stock_scope.select(:product_id).distinct.count
    total_stocks = stock_scope.count

    products_with_insales_mapping = InsalesProductMapping.count
    images_with_insales_mapping = InsalesImageMapping.count
    settings = InsalesSetting.first

    panel "Test store sync status (#{store_name})" do
      table_for [
        ['InSales Base URL', settings&.base_url || '—'],
        ['InSales Category ID', settings&.category_id || '—'],
        ['InSales Collection ID', settings&.default_collection_id || '—'],
        ['Last stock sync', last_stock_sync_at || '—'],
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
end
