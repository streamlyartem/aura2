# frozen_string_literal: true

ActiveAdmin.register_page 'InSales API v1 Monitor' do
  menu parent: 'InSales', label: 'Мониторинг миграции API v1', priority: 99,
       if: proc { current_admin_user&.can_access_admin_path?('/admin/insales_api_v1_monitor') }

  page_action :stop_syncs, method: :post do
    now = Time.current
    stop_message = 'Stopped manually from API v1 monitor'

    running_insales_scope = InsalesSyncRun.where(status: 'running')
    insales_store_names = running_insales_scope.distinct.pluck(:store_name)
    stopped_insales_runs = running_insales_scope.update_all(
      status: 'stopped',
      finished_at: now,
      last_error: stop_message,
      updated_at: now
    )

    InsalesStockSyncState.where(store_name: insales_store_names).update_all(
      last_status: 'stopped',
      last_error: stop_message,
      last_run_at: now,
      updated_at: now
    )

    stopped_moysklad_runs = MoyskladSyncRun.imports.running.update_all(
      stop_requested_at: now,
      updated_at: now
    )

    stoppable_job_classes = [
      'Insales::SyncProductStocksJob',
      'Moysklad::ImportProductsJob',
      'Insales::ApiV1::UpsertBatchJob',
      'Insales::ApiV1::FullSyncJob'
    ]
    job_ids = (
      SolidQueue::ReadyExecution.joins(:job).where(solid_queue_jobs: { class_name: stoppable_job_classes }).pluck(:job_id) +
      SolidQueue::ScheduledExecution.joins(:job).where(solid_queue_jobs: { class_name: stoppable_job_classes }).pluck(:job_id) +
      SolidQueue::ClaimedExecution.joins(:job).where(solid_queue_jobs: { class_name: stoppable_job_classes }).pluck(:job_id) +
      SolidQueue::BlockedExecution.joins(:job).where(solid_queue_jobs: { class_name: stoppable_job_classes }).pluck(:job_id)
    ).uniq

    if job_ids.any?
      SolidQueue::ClaimedExecution.where(job_id: job_ids).delete_all
      SolidQueue::ReadyExecution.where(job_id: job_ids).delete_all
      SolidQueue::ScheduledExecution.where(job_id: job_ids).delete_all
      SolidQueue::BlockedExecution.where(job_id: job_ids).delete_all
      SolidQueue::Job.where(id: job_ids).update_all(finished_at: now, updated_at: now)
    end

    redirect_to admin_insales_api_v1_monitor_path,
                notice: "Остановлено: InSales run=#{stopped_insales_runs}, MoySklad import=#{stopped_moysklad_runs}, jobs=#{job_ids.size}"
  end

  content title: 'Мониторинг миграции API v1' do
    now = Time.current

    api_v1_flags = {
      'INSALES_API_V1_READ_ENABLED' => ENV['INSALES_API_V1_READ_ENABLED'],
      'INSALES_API_V1_WRITE_ENABLED' => ENV['INSALES_API_V1_WRITE_ENABLED'],
      'INSALES_OUTBOX_ENABLED' => ENV['INSALES_OUTBOX_ENABLED'],
      'INSALES_API_V1_FULL_SYNC_ENABLED' => ENV['INSALES_API_V1_FULL_SYNC_ENABLED']
    }

    queue_scopes = [
      SolidQueue::ReadyExecution.joins(:job),
      SolidQueue::ScheduledExecution.joins(:job),
      SolidQueue::ClaimedExecution.joins(:job),
      SolidQueue::BlockedExecution.joins(:job)
    ]

    api_job_classes = ['Insales::ApiV1::UpsertBatchJob', 'Insales::ApiV1::FullSyncJob']
    api_jobs_in_queue = queue_scopes.sum do |scope|
      scope.where(solid_queue_jobs: { class_name: api_job_classes }).count
    end

    outbox_pending = SyncOutboxEvent.where(processed_at: nil).count
    outbox_processed_1h = SyncOutboxEvent.where.not(processed_at: nil).where('processed_at >= ?', 1.hour.ago).count
    outbox_retry_due = SyncOutboxEvent.where(processed_at: nil).where('next_retry_at <= ?', now).count

    idempotency_24h = SyncIdempotencyKey.where('created_at >= ?', 24.hours.ago).count
    idempotency_replayed = SyncIdempotencyKey.where.not(response_status: nil).where('created_at >= ?', 24.hours.ago).count

    runs_24h = InsalesApiSyncRun.where('created_at >= ?', 24.hours.ago)
    runs_running = runs_24h.where(status: 'running').count
    runs_failed = runs_24h.where(status: 'failed').count
    runs_success = runs_24h.where(status: 'success').count

    panel 'Обновление' do
      para 'Страница обновляется автоматически каждые 15 секунд.'
      para "Последнее обновление: #{now.strftime('%d.%m.%Y %H:%M:%S')}"
      div class: 'mb-3' do
        form action: admin_insales_api_v1_monitor_stop_syncs_path, method: :post do
          input type: 'hidden', name: 'authenticity_token', value: form_authenticity_token
          input type: 'submit', value: 'Остановить все синхронизации', class: 'button',
                data: { confirm: 'Остановить активные синхронизации и импорты?' }
        end
      end
    end

    panel 'Флаги API v1' do
      table_for(api_v1_flags) do
        column('Переменная') { |row| row[0] }
        column('Значение') { |row| status_tag(row[1].to_s, class: (row[1].to_s == 'true' ? 'green' : 'orange')) }
      end
    end

    panel 'Ключевые метрики миграции' do
      table_for([
                  ['Очередь API v1 jobs', api_jobs_in_queue],
                  ['Outbox pending', outbox_pending],
                  ['Outbox processed за 1 час', outbox_processed_1h],
                  ['Outbox retry due', outbox_retry_due],
                  ['Idempotency keys за 24ч', idempotency_24h],
                  ['Idempotency replay за 24ч', idempotency_replayed],
                  ['Runs API v1 running (24ч)', runs_running],
                  ['Runs API v1 success (24ч)', runs_success],
                  ['Runs API v1 failed (24ч)', runs_failed]
                ]) do
        column('Метрика') { |row| row[0] }
        column('Значение') { |row| row[1] }
      end
    end

    panel 'Последние запуски API v1' do
      runs = InsalesApiSyncRun.order(created_at: :desc).limit(30)
      if runs.empty?
        para 'Запусков пока нет.'
      else
        table_for(runs) do
          column('ID') { |run| run.id }
          column('Тип') { |run| run.run_type }
          column('Статус') { |run| status_tag(run.status, class: (run.status == 'failed' ? 'red' : run.status == 'running' ? 'orange' : 'green')) }
          column('Batch') { |run| run.batch_id.presence || '—' }
          column('Processed') { |run| "#{run.processed}/#{run.total_items}" }
          column('Created') { |run| run.created_count }
          column('Updated') { |run| run.updated_count }
          column('Unchanged') { |run| run.unchanged_count }
          column('Skipped') { |run| run.skipped_count }
          column('Failed') { |run| run.failed_count }
          column('Последняя ошибка') { |run| run.last_error.to_s.truncate(80) }
          column('Создан') { |run| run.created_at.strftime('%d.%m.%Y %H:%M:%S') }
        end
      end
    end

    script do
      raw <<~JS
        setTimeout(function() {
          window.location.reload();
        }, 15000);
      JS
    end
  end
end
