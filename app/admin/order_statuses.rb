# frozen_string_literal: true

ActiveAdmin.register_page 'Order Statuses' do
  menu parent: 'Заказы', label: 'Статусы', priority: 52,
       if: proc { current_admin_user&.can_access_admin_path?('/admin/order_statuses') }

  content title: 'Статусы заказов' do
    q = params[:q].to_s.strip
    status_filter = params[:status].to_s.strip
    payment_filter = params[:payment_status].to_s.strip

    scope = ExternalOrder.includes(:external_fulfillment_operations).order(last_event_at: :desc, created_at: :desc)
    scope = scope.where('external_order_number ILIKE ? OR external_order_id ILIKE ?', "%#{q}%", "%#{q}%") if q.present?
    scope = scope.where(status: status_filter) if status_filter.present?
    scope = scope.where(payment_status: payment_filter) if payment_filter.present?

    status_counts = ExternalOrder.group(:status).count
    payment_counts = ExternalOrder.group(:payment_status).count
    recent = scope.limit(200)

    panel 'Сводка' do
      table_for [
        ['Всего заказов', ExternalOrder.count],
        ['Событий заказов', ExternalOrderEvent.count],
        ['Операций списания', ExternalFulfillmentOperation.count],
        ['Успешные списания', ExternalFulfillmentOperation.where(status: 'succeeded').count],
        ['Ошибки списаний', ExternalFulfillmentOperation.where("status LIKE 'failed%'").count]
      ] do
        column('Показатель') { |row| row[0] }
        column('Значение') { |row| row[1] }
      end
    end

    panel 'Фильтры' do
      form action: admin_order_statuses_path, method: :get do
        div style: 'display:flex; gap:12px; align-items:flex-end; flex-wrap:wrap;' do
          div style: 'min-width:260px; flex:1 1 260px;' do
            label 'Поиск (номер/ID)'
            input type: 'text', name: 'q', value: q
          end

          div style: 'min-width:200px;' do
            label 'Статус заказа'
            select name: 'status' do
              option 'Все', value: '', selected: status_filter.blank?
              status_counts.keys.compact.sort.each do |value|
                option value, value: value, selected: value == status_filter
              end
            end
          end

          div style: 'min-width:220px;' do
            label 'Статус оплаты'
            select name: 'payment_status' do
              option 'Все', value: '', selected: payment_filter.blank?
              payment_counts.keys.compact.sort.each do |value|
                option value, value: value, selected: value == payment_filter
              end
            end
          end

          div style: 'display:flex; align-items:flex-end; height:42px;' do
            input type: 'submit', value: 'Показать', class: 'button'
          end
        end
      end
    end

    panel 'Последние заказы' do
      if recent.empty?
        para 'Данных пока нет.'
      else
        table_for recent do
          column('Источник', &:source)
          column('Номер') { |row| row.external_order_number.presence || row.external_order_id }
          column('Статус') { |row| row.status }
          column('Оплата') { |row| row.payment_status.presence || '—' }
          column('Сумма') { |row| row.total_minor.present? ? format('%.2f', row.total_minor.to_i / 100.0) : '—' }
          column('Валюта') { |row| row.currency }
          column('Списания') { |row| row.external_fulfillment_operations.size }
          column('Последнее событие') { |row| row.last_event_at || '—' }
        end
      end
    end
  end
end
