# frozen_string_literal: true

ActiveAdmin.register_page 'InSales Stock Sync' do
  menu parent: 'InSales', label: 'InSales Stock Sync', priority: 3,
       if: proc { current_admin_user&.can_access_admin_path?('/admin/insales_stock_sync') }

  page_action :sync_now, method: :post do
    InsalesSyncRun.recover_stale_runs!
    settings = InsalesSetting.first
    store_names = settings&.allowed_store_names_list
    store_names = [MoyskladClient::TEST_STORE_NAME] if store_names.blank?
    Insales::SyncProductStocksJob.perform_later(store_names: store_names)
    redirect_to admin_insales_stock_sync_path,
                notice: "Запущена синхронизация складов: #{store_names.join(', ')}. Обновите страницу через несколько секунд."
  end

  content title: 'Синхронизация остатков (InSales)' do
    InsalesSyncRun.recover_stale_runs!

    store_names = ProductStock.distinct.order(:store_name).pluck(:store_name)
    settings = InsalesSetting.first
    allowed_store_names = settings&.allowed_store_names_list
    allowed_store_names = [MoyskladClient::TEST_STORE_NAME] if allowed_store_names.blank?

    stock_scope = ProductStock.where(store_name: allowed_store_names)
    products_with_stock = stock_scope.select(:product_id).distinct.count
    total_stocks = stock_scope.count

    products_with_insales_mapping = InsalesProductMapping.count
    images_with_insales_mapping = InsalesImageMapping.count
    state = InsalesStockSyncState.find_by(store_name: allowed_store_names.join(', '))
    last_run = InsalesSyncRun.where(store_name: allowed_store_names.join(', ')).order(created_at: :desc).first

    panel 'Синхронизация остатков (InSales)' do
      div class: 'mb-4' do
        form action: admin_insales_stock_sync_sync_now_path, method: :post do
          input type: 'hidden', name: 'authenticity_token', value: form_authenticity_token
          div class: 'mb-2' do
            label 'Активные склады'
            span allowed_store_names.join(', ')
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
        ['Last sync run', last_run&.started_at || state&.last_run_at || '—'],
        ['Last sync finished', last_run&.finished_at || '—'],
        ['Status', last_run&.status || state&.last_status || '—'],
        ['Last HTTP endpoint', state&.last_http_endpoint || '—'],
        ['Last HTTP status', state&.last_http_status || '—'],
        ['Last verified at', state&.last_verified_at || '—']
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
        ['Images uploaded', state&.images_uploaded || '—'],
        ['Images skipped', state&.images_skipped || '—'],
        ['Images errors', state&.images_errors || '—'],
        ['Videos uploaded', state&.videos_uploaded || '—'],
        ['Videos skipped', state&.videos_skipped || '—'],
        ['Verify failures', state&.verify_failures || '—'],
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
