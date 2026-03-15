# frozen_string_literal: true

ActiveAdmin.register_page 'Orders' do
  menu parent: 'Заказы', label: 'Заказы', priority: 50,
       if: proc { current_admin_user&.can_access_admin_path?('/admin/orders') }

  content title: 'Заказы' do
    q = params[:q].to_s.strip
    source_filter = params[:source].to_s.strip

    scope = ExternalOrder.order(last_event_at: :desc, created_at: :desc)
    scope = scope.where(source: source_filter) if source_filter.present?
    if q.present?
      scope = scope.where(
        'external_order_number ILIKE :q OR external_order_id ILIKE :q',
        q: "%#{q}%"
      )
    end

    orders = scope.limit(200)
    sources = ExternalOrder.distinct.order(:source).pluck(:source)

    panel 'Фильтры' do
      form action: admin_orders_path, method: :get do
        div style: 'display:flex; gap:12px; align-items:flex-end; flex-wrap:wrap;' do
          div style: 'min-width:320px; flex:1 1 320px;' do
            label 'Поиск (номер/ID)'
            input type: 'text', name: 'q', value: q
          end
          div style: 'min-width:220px;' do
            label 'Источник'
            select name: 'source' do
              option 'Все', value: '', selected: source_filter.blank?
              sources.each do |value|
                option value, value: value, selected: value == source_filter
              end
            end
          end
          div style: 'display:flex; align-items:flex-end; height:42px;' do
            input type: 'submit', value: 'Показать', class: 'button'
          end
        end
      end
    end

    panel 'Заказы со всех витрин' do
      if orders.empty?
        para 'Данных пока нет.'
      else
        table_for orders do
          column('Источник', &:source)
          column('Номер') { |row| row.external_order_number.presence || row.external_order_id }
          column('Статус') { |row| row.status }
          column('Оплата') { |row| row.payment_status.presence || '—' }
          column('Сумма') { |row| row.total_minor.present? ? format('%.2f', row.total_minor.to_i / 100.0) : '—' }
          column('Валюта', &:currency)
          column('Последнее событие') { |row| row.last_event_at || '—' }
        end
      end
    end
  end
end
