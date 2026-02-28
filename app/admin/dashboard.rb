# frozen_string_literal: true

ActiveAdmin.register_page 'Dashboard' do
  menu priority: 1, label: proc { I18n.t('active_admin.dashboard') },
       if: proc { current_admin_user&.can_access_admin_path?('/admin/dashboard') }

  page_action :stop_syncs, method: :post do
    now = Time.current
    stop_message = 'Stopped manually from dashboard'

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
      'Moysklad::ImportProductsJob'
    ]
    jobs_scope = SolidQueue::Job.where(class_name: stoppable_job_classes, finished_at: nil)
    job_ids = jobs_scope.pluck(:id)

    if job_ids.any?
      SolidQueue::ClaimedExecution.where(job_id: job_ids).delete_all
      SolidQueue::ReadyExecution.where(job_id: job_ids).delete_all
      SolidQueue::ScheduledExecution.where(job_id: job_ids).delete_all
      SolidQueue::BlockedExecution.where(job_id: job_ids).delete_all
      SolidQueue::Job.where(id: job_ids).update_all(finished_at: now, updated_at: now)
    end

    redirect_to admin_dashboard_path, notice: "Остановлено: InSales run=#{stopped_insales_runs}, MoySklad import=#{stopped_moysklad_runs}, jobs=#{job_ids.size}"
  end

  content title: proc { I18n.t('active_admin.dashboard') } do
    InsalesSyncRun.recover_stale_runs!
    health = Monitoring::HealthSnapshot.call

    queue_scope = SolidQueue::Job.where(finished_at: nil)
    queue_total = queue_scope.count
    queue_ready = SolidQueue::ReadyExecution.count
    queue_scheduled = SolidQueue::ScheduledExecution.count
    queue_claimed = SolidQueue::ClaimedExecution.count
    queue_blocked = SolidQueue::BlockedExecution.count

    running_moysklad_imports = MoyskladSyncRun.imports.running.order(started_at: :asc).to_a
    running_insales_syncs = InsalesSyncRun.where(status: 'running').order(started_at: :asc).to_a

    panel 'Состояние системы' do
      div class: 'mb-3' do
        form action: admin_dashboard_stop_syncs_path, method: :post do
          input type: 'hidden', name: 'authenticity_token', value: form_authenticity_token
          input type: 'submit', value: 'Остановить синхронизации', class: 'button'
        end
      end

      table_for [
        ['Импорт МойСклад (running)', running_moysklad_imports.size],
        ['Синк InSales (running)', running_insales_syncs.size],
        ['Очередь задач (всего)', queue_total],
        ['Очередь: ready', queue_ready],
        ['Очередь: scheduled', queue_scheduled],
        ['Очередь: claimed (в работе)', queue_claimed],
        ['Очередь: blocked', queue_blocked]
      ] do
        column('Показатель') { |row| row[0] }
        column('Значение') { |row| row[1] }
      end
    end

    panel 'Health' do
      table_for [
        ['Sentry', health[:sentry_enabled] ? 'enabled' : 'disabled'],
        ['Stock events pending (high)', health[:stock_events_pending_high]],
        ['Stock events pending (normal)', health[:stock_events_pending_normal]],
        ['Stock events processing', health[:stock_events_processing]],
        ['Stock events failed', health[:stock_events_failed]],
        ['Stale InSales sync runs', health[:stale_insales_sync_runs]],
        ['InSales failed jobs', health[:insales_failed_jobs]],
        ['MoySklad failed jobs', health[:moysklad_failed_jobs]],
        ['Failed jobs (24h)', health[:failed_jobs_last_24h]],
        ['P95 InSales sync (sec)', health[:p95_insales_sync_seconds] || '—']
      ] do
        column('Метрика') { |row| row[0] }
        column('Значение') { |row| row[1] }
      end
    end

    panel 'Активные процессы' do
      if running_moysklad_imports.empty? && running_insales_syncs.empty?
        para 'Сейчас активных процессов нет.'
      else
        table_for(
          running_moysklad_imports.map { |run| ['MoySklad import', run.id, run.status, run.started_at, run.stop_requested_at] } +
          running_insales_syncs.map { |run| ["InSales sync (#{run.store_name})", run.id, run.status, run.started_at, nil] }
        ) do
          column('Процесс') { |row| row[0] }
          column('ID') { |row| row[1] }
          column('Статус') { |row| row[2] }
          column('Запущен') { |row| row[3] }
          column('Stop requested at') { |row| row[4] || '—' }
        end
      end
    end

    panel 'Очередь задач (по классам)' do
      grouped = queue_scope.group(:class_name).order(Arel.sql('count_all DESC')).count
      if grouped.empty?
        para 'Очередь пустая.'
      else
        table_for(grouped.to_a) do
          column('Класс job') { |row| row[0] }
          column('Кол-во') { |row| row[1] }
        end
      end
    end

    panel 'Очередь задач (список)' do
      if queue_total.zero?
        para 'Очередь пустая.'
      elsif queue_total > 40
        para "Сейчас в очереди #{queue_total} задач. Список скрыт (порог: 40), чтобы не перегружать страницу."
      else
        rows = queue_scope.order(created_at: :asc).limit(40).pluck(:id, :class_name, :queue_name, :created_at, :scheduled_at)
        table_for(rows) do
          column('Job ID') { |row| row[0] }
          column('Класс') { |row| row[1] }
          column('Очередь') { |row| row[2] }
          column('Создано') { |row| row[3] }
          column('Запланировано') { |row| row[4] || '—' }
        end
      end
    end
  end
end
