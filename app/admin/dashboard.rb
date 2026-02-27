# frozen_string_literal: true

ActiveAdmin.register_page 'Dashboard' do
  menu priority: 1, label: proc { I18n.t('active_admin.dashboard') }

  content title: proc { I18n.t('active_admin.dashboard') } do
    queue_scope = SolidQueue::Job.where(finished_at: nil)
    queue_total = queue_scope.count
    queue_ready = SolidQueue::ReadyExecution.count
    queue_scheduled = SolidQueue::ScheduledExecution.count
    queue_claimed = SolidQueue::ClaimedExecution.count
    queue_blocked = SolidQueue::BlockedExecution.count

    running_moysklad_imports = MoyskladSyncRun.imports.running.order(started_at: :asc).to_a
    running_insales_syncs = InsalesSyncRun.where(status: 'running').order(started_at: :asc).to_a

    panel 'Состояние системы' do
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
