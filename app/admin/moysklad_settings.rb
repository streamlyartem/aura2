# frozen_string_literal: true

ActiveAdmin.register_page 'MoySklad Settings' do
  menu label: 'Настройки МС', parent: 'МойСклад', priority: 2

  page_action :ensure_webhooks, method: :post do
    Moysklad::EnsureWebhooksJob.perform_later
    redirect_to admin_moysklad_settings_path, notice: 'Запущена задача создания вебхуков'
  end

  page_action :import_products, method: :post do
    selected_store_names = MoyskladStore.selected_names

    if selected_store_names.empty?
      redirect_to admin_moysklad_settings_path, alert: 'Выберите хотя бы один склад в разделе "Склады МС".'
      next
    end

    all_store_names = begin
      MoyskladClient.new.store_names
    rescue StandardError => e
      Rails.logger.warn("[MoyskladSettings] Failed to load MoySklad stores: #{e.class} - #{e.message}")
      MoyskladStore.all_names
    end
    all_store_names = Array(all_store_names).map(&:to_s).map(&:strip).reject(&:blank?).uniq

    if all_store_names.empty?
      redirect_to admin_moysklad_settings_path, alert: 'Список складов пуст. Нажмите "Обновить список" в разделе "Склады МС".'
      next
    end

    full_import = all_store_names.present? && (all_store_names - selected_store_names).empty?

    notice = if Moysklad::ImportProductsJob.enqueue_once(
      store_names: selected_store_names,
      full_import: full_import
    )
               if full_import
                 'Запущен полный импорт товаров из MoySklad (выбраны все склады)'
               else
                 "Запущен импорт товаров по выбранным складам: #{selected_store_names.join(', ')}"
               end
             else
               'Импорт уже запущен или находится в очереди'
             end

    redirect_to admin_moysklad_settings_path, notice: notice
  end

  page_action :stop_import, method: :post do
    running_run = MoyskladSyncRun.imports.running.order(created_at: :desc).first

    notice = if running_run.nil?
               'Сейчас нет активного импорта'
             elsif running_run.stop_requested?
               'Запрос на остановку уже отправлен'
             else
               running_run.update!(stop_requested_at: Time.current)
               'Запрос на остановку импорта отправлен'
             end

    redirect_to admin_moysklad_settings_path, notice: notice
  end

  content title: 'MoySklad Settings' do
    webhook_token = ENV['MOYSKLAD_WEBHOOK_TOKEN'].to_s
    webhook_host = ENV['APP_HOST'].presence || ENV['RAILS_HOST'].presence || Rails.application.routes.default_url_options[:host]
    webhook_base = ENV['MOYSKLAD_WEBHOOK_URL'].presence || (webhook_host.present? ? "https://#{webhook_host}/api/moysklad/webhooks" : '—')
    masked_token = webhook_token.present? ? "****#{webhook_token[-4, 4]}" : '—'
    webhook_hint = webhook_base == '—' ? '—' : "#{webhook_base}?token=#{masked_token}"

    last_webhooks_run = MoyskladSyncRun.where(run_type: 'webhooks').order(created_at: :desc).first
    last_import_run = MoyskladSyncRun.where(run_type: 'import_products').order(created_at: :desc).first
    running_import_run = MoyskladSyncRun.imports.running.order(created_at: :desc).first
    selected_store_names = MoyskladStore.selected_names

    sync_run_time = lambda do |run|
      next '—' unless run&.status == 'running' && run.started_at.present?

      "#{(Time.current - run.started_at).to_i} sec"
    end

    last_sync_run_at = lambda do |run|
      run&.finished_at || run&.started_at || '—'
    end

    panel 'Управление вебхуками' do
      div class: 'mb-4' do
        form action: url_for(action: :ensure_webhooks), method: :post do
          input type: 'hidden', name: 'authenticity_token', value: form_authenticity_token
          input type: 'submit', value: 'Подключить вебхуки', class: 'button'
        end
      end

      table_for [
        ['MoySklad Webhook URL', webhook_hint],
        ['Last sync run', last_sync_run_at.call(last_webhooks_run)],
        ['Status', last_webhooks_run&.status || '—'],
        ['Sync run time', sync_run_time.call(last_webhooks_run)],
        ['Processed', last_webhooks_run&.processed || '—'],
        ['Created', last_webhooks_run&.created || '—'],
        ['Errors', last_webhooks_run&.error_count || '—'],
        ['Last error', last_webhooks_run&.status == 'failed' ? (last_webhooks_run.last_error.presence || '—') : '—']
      ] do
        column('Metric') { |row| row[0] }
        column('Value') { |row| row[1] }
      end
    end

    panel 'Импорт товаров из MoySklad' do
      div class: 'mb-4' do
        form action: url_for(action: :import_products), method: :post do
          input type: 'hidden', name: 'authenticity_token', value: form_authenticity_token
          input type: 'submit', value: 'Импортировать товары из MoySklad', class: 'button'
        end
      end

      if running_import_run.present?
        div class: 'mb-4' do
          form action: url_for(action: :stop_import), method: :post do
            input type: 'hidden', name: 'authenticity_token', value: form_authenticity_token
            input type: 'submit',
                  value: (running_import_run.stop_requested? ? 'Остановка запрошена' : 'Остановить импорт'),
                  class: 'button',
                  disabled: running_import_run.stop_requested?
          end
        end
      end

      table_for [
        ['Last sync run', last_sync_run_at.call(last_import_run)],
        ['Status', last_import_run&.status || '—'],
        ['Sync run time', sync_run_time.call(last_import_run)],
        ['Склады для импорта', selected_store_names.present? ? selected_store_names.join(', ') : '—'],
        ['Processed', last_import_run&.processed || '—'],
        ['Errors', last_import_run&.error_count || '—'],
        ['Last error', last_import_run&.status == 'failed' ? (last_import_run.last_error.presence || '—') : '—'],
        ['Товаров в AURA', Product.count],
        ['Товаров на MoySklad', '—']
      ] do
        column('Metric') { |row| row[0] }
        column('Value') { |row| row[1] }
      end
    end
  end
end
