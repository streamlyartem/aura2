# frozen_string_literal: true

ActiveAdmin.register_page 'Insales Sync' do
  menu false

  controller do
    def index
      redirect_to admin_insales_stock_sync_path
    end
  end

  page_action :sync_now, method: :post do
    settings = InsalesSetting.first
    store_names = settings&.allowed_store_names_list
    store_names = [MoyskladClient::TEST_STORE_NAME] if store_names.blank?

    Insales::SyncProductStocksJob.perform_later(store_names: store_names)

    redirect_to admin_insales_sync_path, notice: "Запущена синхронизация складов: #{store_names.join(', ')}"
  end

  page_action :ensure_moysklad_webhooks, method: :post do
    Moysklad::EnsureWebhooksJob.perform_later

    redirect_to admin_insales_sync_path(store_name: params[:store_name].presence), notice: 'MoySklad webhooks enqueued'
  end

  page_action :import_moysklad_products, method: :post do
    selected_store_names = MoyskladStore.selected_names

    notice = if selected_store_names.blank?
               'Выберите склады в разделе "Склады МС"'
             else
               all_store_names = begin
                 MoyskladClient.new.store_names
               rescue StandardError
                 MoyskladStore.all_names
               end
               full_import = (Array(all_store_names).map(&:to_s).map(&:strip).reject(&:blank?) - selected_store_names).empty?

               if Moysklad::ImportProductsJob.enqueue_once(store_names: selected_store_names, full_import: full_import)
                 'Импорт товаров из MoySklad запущен'
               else
                 'Импорт уже запущен или находится в очереди'
               end
             end

    redirect_to admin_insales_sync_path(store_name: params[:store_name].presence), notice: notice
  end

  action_item :ensure_moysklad_webhooks, only: :index do
    link_to 'Подключить вебхуки MoySklad (staging)', url_for(action: :ensure_moysklad_webhooks, store_name: params[:store_name]), method: :post
  end

  action_item :import_moysklad_products, only: :index do
    link_to 'Импортировать товары из MoySklad', url_for(action: :import_moysklad_products, store_name: params[:store_name]), method: :post
  end

  content title: 'InSales Sync' do
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
    webhook_token = ENV['MOYSKLAD_WEBHOOK_TOKEN'].to_s
    webhook_host = ENV['APP_HOST'].presence || ENV['RAILS_HOST'].presence || Rails.application.routes.default_url_options[:host]
    webhook_base = ENV['MOYSKLAD_WEBHOOK_URL'].presence || (webhook_host.present? ? "https://#{webhook_host}/api/moysklad/webhooks" : '—')
    masked_token = webhook_token.present? ? "****#{webhook_token[-4, 4]}" : '—'
    webhook_hint = webhook_base == '—' ? '—' : "#{webhook_base}?token=#{masked_token}"

    panel 'Синхронизация остатков (InSales)' do
      div class: 'mb-4' do
        form action: url_for(action: :sync_now), method: :post do
          input type: 'hidden', name: 'authenticity_token', value: form_authenticity_token
          div class: 'mb-2' do
            label 'Активные склады'
            span allowed_store_names.join(', ')
          end
          input type: 'submit', value: 'Синхронизировать', class: 'button'
        end
      end

      table_for [
        ['InSales Base URL', settings&.base_url || '—'],
        ['InSales Category ID', settings&.category_id || '—'],
        ['InSales Collection ID', settings&.default_collection_id || '—'],
        ['MoySklad Webhook URL', webhook_hint],
        ['Last stock sync', state&.last_stock_sync_at || '—'],
        ['Last sync run', state&.last_run_at || '—'],
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
