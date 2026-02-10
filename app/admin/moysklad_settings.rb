# frozen_string_literal: true

ActiveAdmin.register_page 'MoySklad Settings' do
  menu label: 'MoySklad Settings', priority: 6

  page_action :ensure_webhooks, method: :post do
    Moysklad::EnsureWebhooksJob.perform_later
    redirect_to admin_moysklad_settings_path, notice: 'Запущена задача создания вебхуков'
  end

  page_action :import_products, method: :post do
    Moysklad::ImportProductsJob.perform_later
    redirect_to admin_moysklad_settings_path, notice: 'Запущен импорт товаров из MoySklad'
  end

  content title: 'MoySklad Settings' do
    webhook_token = ENV['MOYSKLAD_WEBHOOK_TOKEN'].to_s
    webhook_host = ENV['APP_HOST'].presence || ENV['RAILS_HOST'].presence || Rails.application.routes.default_url_options[:host]
    webhook_base = ENV['MOYSKLAD_WEBHOOK_URL'].presence || (webhook_host.present? ? "https://#{webhook_host}/api/moysklad/webhooks" : '—')
    masked_token = webhook_token.present? ? "****#{webhook_token[-4, 4]}" : '—'
    webhook_hint = webhook_base == '—' ? '—' : "#{webhook_base}?token=#{masked_token}"

    last_webhooks_run = MoyskladSyncRun.where(run_type: 'webhooks').order(created_at: :desc).first
    last_import_run = MoyskladSyncRun.where(run_type: 'import_products').order(created_at: :desc).first

    panel 'Управление вебхуками' do
      div class: 'mb-4' do
        form action: url_for(action: :ensure_webhooks), method: :post do
          input type: 'hidden', name: 'authenticity_token', value: form_authenticity_token
          input type: 'submit', value: 'Подключить вебхуки', class: 'button'
        end
      end

      table_for [
        ['MoySklad Webhook URL', webhook_hint],
        ['Last sync run', last_webhooks_run&.finished_at || '—'],
        ['Status', last_webhooks_run&.status || '—'],
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

      table_for [
        ['Last sync run', last_import_run&.finished_at || '—'],
        ['Status', last_import_run&.status || '—'],
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
