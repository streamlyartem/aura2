# frozen_string_literal: true

ActiveAdmin.register_page 'InSales Stock Sync' do
  menu label: 'InSales Stock Sync', priority: 6

  page_action :sync_now, method: :post do
    store_name = params[:store_name].presence || 'Тест'
    Insales::SyncProductStocksJob.perform_later(store_name: store_name)
    redirect_to admin_insales_stock_sync_path(store_name: store_name),
                notice: "Запущена синхронизация склада #{store_name}. Обновите страницу через несколько секунд."
  end

  content title: 'Синхронизация остатков (InSales)' do
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
        form action: admin_insales_stock_sync_sync_now_path, method: :post do
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
end
