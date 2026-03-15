# frozen_string_literal: true

ActiveAdmin.register_page 'Dashboard' do
  menu priority: 1, label: proc { I18n.t('active_admin.dashboard') },
       if: proc { current_admin_user&.can_access_admin_path?('/admin/dashboard') }

  page_action :stop_syncs, method: %i[get post] do
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

    redirect_to admin_dashboard_path, notice: "Остановлено: InSales run=#{stopped_insales_runs}, MoySklad import=#{stopped_moysklad_runs}, jobs=#{job_ids.size}"
  end

  content title: proc { I18n.t('active_admin.dashboard') } do
    InsalesSyncRun.recover_stale_runs!
    health = Monitoring::HealthSnapshot.call
    now = Time.current

    queue_ready = SolidQueue::ReadyExecution.count
    queue_scheduled = SolidQueue::ScheduledExecution.count
    queue_claimed = SolidQueue::ClaimedExecution.count
    queue_blocked = SolidQueue::BlockedExecution.count
    queue_total = queue_ready + queue_scheduled + queue_claimed + queue_blocked

    running_moysklad_imports = MoyskladSyncRun.imports.running.order(started_at: :asc).to_a
    running_insales_syncs = InsalesSyncRun.where(status: 'running').order(started_at: :asc).to_a

    format_duration = lambda do |started_at|
      next '—' if started_at.blank?

      seconds = (now - started_at).to_i
      return "#{seconds} сек" if seconds < 60

      minutes = seconds / 60
      return "#{minutes} мин" if minutes < 60

      hours = minutes / 60
      rem_minutes = minutes % 60
      "#{hours} ч #{rem_minutes} мин"
    end

    severity_for = lambda do |value, warning_from:, danger_from:|
      return :ok if value.to_i < warning_from
      return :warning if value.to_i < danger_from

      :error
    end

    render_badge = lambda do |label, value, severity|
      css_class = case severity
                  when :error then 'red'
                  when :warning then 'orange'
                  else 'green'
                  end

      [label, status_tag(value, class: css_class)]
    end

    queue_severity = severity_for.call(queue_total, warning_from: 20, danger_from: 60)
    failed_jobs_severity = severity_for.call(health[:failed_jobs_last_24h], warning_from: 1, danger_from: 10)
    pending_high_severity = severity_for.call(health[:stock_events_pending_high], warning_from: 1, danger_from: 20)
    stale_runs_severity = severity_for.call(health[:stale_insales_sync_runs], warning_from: 1, danger_from: 3)
    stock_failed_severity = severity_for.call(health[:stock_events_failed], warning_from: 1, danger_from: 5)

    panel 'Оперативная сводка' do
      stop_button_style = 'display:inline-block;padding:10px 14px;border-radius:6px;background:#2563eb;color:#ffffff;text-decoration:none;font-weight:600;border:1px solid #1d4ed8;line-height:1.2;cursor:pointer;'
      div class: 'mb-3' do
        form action: admin_dashboard_stop_syncs_path, method: :post, style: 'display:inline-block;' do
          input type: 'hidden', name: 'authenticity_token', value: form_authenticity_token
          button 'Остановить все синхронизации',
                 type: 'submit',
                 style: stop_button_style,
                 onclick: "return confirm('Остановить все активные синхронизации и импорты?')"
        end
        para 'Останавливает активные импорты MoySklad и синхронизации InSales. Другие задачи не затрагиваются.'
      end

      table_for [
        ['Активные импорты МойСклад', running_moysklad_imports.size],
        ['Активные синки InSales', running_insales_syncs.size],
        render_badge.call('Очередь задач: всего', queue_total, queue_severity),
        ['Очередь: ready', queue_ready],
        ['Очередь: scheduled', queue_scheduled],
        ['Очередь: claimed (выполняется)', queue_claimed],
        ['Очередь: blocked', queue_blocked],
        render_badge.call('Упавшие задачи за 24 часа', health[:failed_jobs_last_24h], failed_jobs_severity),
        render_badge.call('События остатков: pending high', health[:stock_events_pending_high], pending_high_severity)
      ] do
        column('Показатель') { |row| row[0] }
        column('Значение') { |row| row[1] }
      end
    end

    panel 'Здоровье системы' do
      table_for [
        ['Sentry', health[:sentry_enabled] ? 'включен' : 'выключен'],
        render_badge.call('События остатков: pending high', health[:stock_events_pending_high], pending_high_severity),
        ['События остатков: pending normal', health[:stock_events_pending_normal]],
        ['События остатков: processing', health[:stock_events_processing]],
        render_badge.call('События остатков: failed', health[:stock_events_failed], stock_failed_severity),
        render_badge.call('Подвисшие синки InSales', health[:stale_insales_sync_runs], stale_runs_severity),
        ['Упавшие задачи InSales', health[:insales_failed_jobs]],
        ['Упавшие задачи MoySklad', health[:moysklad_failed_jobs]],
        render_badge.call('Упавшие задачи за 24 часа', health[:failed_jobs_last_24h], failed_jobs_severity),
        ['P95 синка InSales (сек)', health[:p95_insales_sync_seconds] || '—']
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
          running_moysklad_imports.map { |run| ['Импорт MoySklad', run.id, run.status, run.started_at, run.stop_requested_at, nil] } +
          running_insales_syncs.map { |run| ["Синк InSales (#{run.store_name})", run.id, run.status, run.started_at, nil, run.updated_at] }
        ) do
          column('Процесс') { |row| row[0] }
          column('ID') { |row| row[1] }
          column('Статус') { |row| row[2] }
          column('Запущен') { |row| row[3]&.strftime('%d.%m.%Y %H:%M:%S') || '—' }
          column('Длительность') { |row| format_duration.call(row[3]) }
          column('Запрошена остановка') { |row| row[4]&.strftime('%d.%m.%Y %H:%M:%S') || '—' }
          column('Обновлён') { |row| row[5]&.strftime('%d.%m.%Y %H:%M:%S') || '—' }
        end
      end
    end

    panel 'Очередь задач (по классам)' do
      grouped = Hash.new(0)
      [
        SolidQueue::ReadyExecution.joins(:job),
        SolidQueue::ScheduledExecution.joins(:job),
        SolidQueue::ClaimedExecution.joins(:job),
        SolidQueue::BlockedExecution.joins(:job)
      ].each do |scope|
        scope.group('solid_queue_jobs.class_name').count.each { |klass, count| grouped[klass] += count }
      end
      grouped = grouped.sort_by { |_klass, count| -count }
      if grouped.empty?
        para 'Очередь пустая.'
      else
        table_for(grouped) do
          column('Класс задачи') { |row| row[0] }
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
        rows = []
        [
          SolidQueue::ReadyExecution.joins(:job).select('solid_queue_jobs.id AS job_id, solid_queue_jobs.class_name, solid_queue_jobs.queue_name, solid_queue_jobs.created_at, solid_queue_jobs.scheduled_at'),
          SolidQueue::ScheduledExecution.joins(:job).select('solid_queue_jobs.id AS job_id, solid_queue_jobs.class_name, solid_queue_jobs.queue_name, solid_queue_jobs.created_at, solid_queue_jobs.scheduled_at'),
          SolidQueue::ClaimedExecution.joins(:job).select('solid_queue_jobs.id AS job_id, solid_queue_jobs.class_name, solid_queue_jobs.queue_name, solid_queue_jobs.created_at, solid_queue_jobs.scheduled_at'),
          SolidQueue::BlockedExecution.joins(:job).select('solid_queue_jobs.id AS job_id, solid_queue_jobs.class_name, solid_queue_jobs.queue_name, solid_queue_jobs.created_at, solid_queue_jobs.scheduled_at')
        ].each do |scope|
          rows.concat(scope.map { |row| [row.job_id, row.class_name, row.queue_name, row.created_at, row.scheduled_at] })
        end

        rows = rows.uniq { |row| row[0] }.sort_by { |row| row[3] }.first(40)
        table_for(rows) do
          column('ID задачи') { |row| row[0] }
          column('Класс') { |row| row[1] }
          column('Очередь') { |row| row[2] }
          column('Создано') { |row| row[3] }
          column('Запланировано') { |row| row[4] || '—' }
        end
      end
    end
  end
end
