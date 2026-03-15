# frozen_string_literal: true

ActiveAdmin.register_page 'Order Write Offs' do
  menu parent: 'Заказы', label: 'Списания', priority: 53,
       if: proc { current_admin_user&.can_access_admin_path?('/admin/order_write_offs') }

  content title: 'Списания по заказам' do
    q = params[:q].to_s.strip
    status_filter = params[:status].to_s.strip

    scope = ExternalFulfillmentOperation.includes(:external_order).order(updated_at: :desc, created_at: :desc)
    scope = scope.where(status: status_filter) if status_filter.present?
    if q.present?
      scope = scope.joins(:external_order).where(
        'external_fulfillment_operations.id::text ILIKE :q OR external_orders.external_order_number ILIKE :q OR external_orders.external_order_id ILIKE :q OR external_fulfillment_operations.ms_document_id ILIKE :q',
        q: "%#{q}%"
      )
    end

    rows = scope.limit(200)
    statuses = ExternalFulfillmentOperation.group(:status).count

    panel 'Сводка списаний' do
      table_for [
        ['Всего операций', ExternalFulfillmentOperation.count],
        ['Очередь (queued)', ExternalFulfillmentOperation.where(status: 'queued').count],
        ['Выполняется (processing)', ExternalFulfillmentOperation.where(status: 'processing').count],
        ['Успешно', ExternalFulfillmentOperation.where(status: 'succeeded').count],
        ['Ошибки', ExternalFulfillmentOperation.where("status LIKE 'failed%'").count]
      ] do
        column('Показатель') { |row| row[0] }
        column('Значение') { |row| row[1] }
      end
    end

    panel 'Фильтры' do
      form action: admin_order_write_offs_path, method: :get do
        div style: 'display:flex; gap:12px; align-items:flex-end; flex-wrap:wrap;' do
          div style: 'min-width:320px; flex:1 1 320px;' do
            label 'Поиск (заказ / документ / id)'
            input type: 'text', name: 'q', value: q
          end

          div style: 'min-width:220px;' do
            label 'Статус'
            select name: 'status' do
              option 'Все', value: '', selected: status_filter.blank?
              statuses.keys.compact.sort.each do |value|
                option value, value: value, selected: value == status_filter
              end
            end
          end

          div style: 'display:flex; align-items:flex-end; height:42px;' do
            input type: 'submit', value: 'Показать', class: 'button'
          end
        end
      end
    end

    panel 'Операции списания' do
      if rows.empty?
        para 'Данных пока нет.'
      else
        table_for rows do
          column('Операция ID', &:id)
          column('Заказ') do |row|
            order = row.external_order
            order&.external_order_number.presence || order&.external_order_id || '—'
          end
          column('Тип', &:operation_type)
          column('Статус', &:status)
          column('MS документ') { |row| row.ms_document_id.presence || '—' }
          column('Попыток', &:attempts)
          column('След. retry') { |row| row.next_retry_at || '—' }
          column('Комментарий') { |row| row.comment.presence || '—' }
          column('Ошибка') { |row| row.last_error.presence || '—' }
          column('Обновлено') { |row| row.updated_at }
        end
      end
    end
  end
end
