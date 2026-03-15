# frozen_string_literal: true

ActiveAdmin.register_page 'InSales Orders' do
  menu parent: 'Заказы', label: 'Заказы InSales', priority: 51,
       if: proc { current_admin_user&.can_access_admin_path?('/admin/insales_orders') }

  content title: 'Заказы InSales' do
    query = params[:q].to_s.strip
    sku = params[:sku].to_s.strip
    page = params[:page].presence || 1
    per_page = (params[:per_page].presence || 50).to_i.clamp(10, 100)

    result = ::Insales::OrdersFeed.new.call(page: page, per_page: per_page, query: query, sku: sku)

    panel 'Фильтры' do
      form action: admin_insales_orders_path, method: :get do
        div style: 'display:flex; gap:12px; align-items:flex-end; flex-wrap:wrap;' do
          div style: 'min-width:320px; flex:1 1 320px;' do
            label 'Поиск (номер, клиент, статус)'
            input type: 'text', name: 'q', value: query
          end

          div style: 'min-width:220px; flex:1 1 220px;' do
            label 'SKU'
            input type: 'text', name: 'sku', value: sku
          end

          div style: 'min-width:140px;' do
            label 'На странице'
            select name: 'per_page' do
              [25, 50, 100].each do |value|
                option value, value: value, selected: value == per_page
              end
            end
          end

          div style: 'display:flex; align-items:flex-end; height:42px;' do
            input type: 'submit', value: 'Показать', class: 'button'
          end
        end
      end
    end

    if result.error.present?
      panel 'Ошибка загрузки' do
        status_tag 'error', label: result.error
      end
    end

    panel 'Статус заказов из InSales' do
      if result.orders.empty?
        para 'Заказы не найдены по текущему фильтру.'
      else
        table_for result.orders do
          column('ID') { |row| row[:id] }
          column('Номер') { |row| row[:number] || '—' }
          column('Создан') { |row| row[:created_at] || '—' }
          column('Статус') { |row| row[:status] || '—' }
          column('Оплата') { |row| row[:financial_status] || '—' }
          column('Отгрузка') { |row| row[:fulfillment_status] || '—' }
          column('Сумма') do |row|
            next '—' if row[:total_price].blank?

            value = row[:total_price]
            currency = row[:currency].presence || 'RUB'
            "#{value} #{currency}"
          end
          column('Клиент') { |row| row[:client_name] || '—' }
          column('Email') { |row| row[:client_email] || '—' }
          column('Телефон') { |row| row[:client_phone] || '—' }
          column('SKU') { |row| row[:skus].presence&.join(', ') || '—' }
        end
      end
    end
  end
end
