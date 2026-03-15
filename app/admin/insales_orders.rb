# frozen_string_literal: true

ActiveAdmin.register_page 'InSales Orders' do
  menu parent: 'Заказы', label: 'Заказы InSales', priority: 51,
       if: proc { current_admin_user&.can_access_admin_path?('/admin/insales_orders') }

  content title: 'Заказы InSales' do
    query = params[:q].to_s.strip
    sku = params[:sku].to_s.strip
    status_filter = params[:status].to_s.strip
    payment_filter = params[:payment_status].to_s.strip
    use_external_orders = ExternalOrder.where(source: 'insales').exists?

    if use_external_orders
      orders_scope = ExternalOrder
        .where(source: 'insales')
        .includes(:external_order_items, :external_fulfillment_operations)
        .order(last_event_at: :desc, created_at: :desc)
      orders_scope = orders_scope.where(status: status_filter) if status_filter.present?
      orders_scope = orders_scope.where(payment_status: payment_filter) if payment_filter.present?
      if query.present?
        orders_scope = orders_scope.where(
          'external_order_number ILIKE :q OR external_order_id ILIKE :q',
          q: "%#{query}%"
        )
      end
      if sku.present?
        orders_scope = orders_scope.joins(:external_order_items).where('external_order_items.sku ILIKE ?', "%#{sku}%").distinct
      end
      orders = orders_scope.limit(200)
      statuses = ExternalOrder.where(source: 'insales').group(:status).count
      payment_statuses = ExternalOrder.where(source: 'insales').group(:payment_status).count
    else
      page = params[:page].presence || 1
      per_page = (params[:per_page].presence || 50).to_i.clamp(10, 100)
      result = ::Insales::OrdersFeed.new.call(page: page, per_page: per_page, query: query, sku: sku)
    end

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

          if use_external_orders
            div style: 'min-width:200px;' do
              label 'Статус'
              select name: 'status' do
                option 'Все', value: '', selected: status_filter.blank?
                statuses.keys.compact.sort.each do |value|
                  option value, value: value, selected: value == status_filter
                end
              end
            end

            div style: 'min-width:220px;' do
              label 'Статус оплаты'
              select name: 'payment_status' do
                option 'Все', value: '', selected: payment_filter.blank?
                payment_statuses.keys.compact.sort.each do |value|
                  option value, value: value, selected: value == payment_filter
                end
              end
            end
          else
            div style: 'min-width:140px;' do
              label 'На странице'
              select name: 'per_page' do
                [25, 50, 100].each do |value|
                  option value, value: value, selected: value == per_page
                end
              end
            end
          end

          div style: 'display:flex; align-items:flex-end; height:42px;' do
            input type: 'submit', value: 'Показать', class: 'button'
          end
        end
      end
    end

    if !use_external_orders && result.error.present?
      panel 'Ошибка загрузки' do
        status_tag 'error', label: result.error
      end
    end

    panel 'Статус заказов из InSales' do
      if use_external_orders && orders.empty?
        para 'Внутренние заказы InSales пока не загружены.'
      elsif !use_external_orders && result.orders.empty?
        para 'Заказы не найдены по текущему фильтру.'
      else
        if use_external_orders
          table_for orders do
            column('ID') { |row| row.external_order_id }
            column('Номер') { |row| row.external_order_number.presence || '—' }
            column('Создан') { |row| row.created_at }
            column('Статус') { |row| row.status || '—' }
            column('Оплата') { |row| row.payment_status || '—' }
            column('Отгрузка') do |row|
              row.external_fulfillment_operations.order(updated_at: :desc).first&.status || '—'
            end
            column('Сумма') do |row|
              next '—' if row.total_minor.blank?

              "#{format('%.2f', row.total_minor.to_i / 100.0)} #{row.currency.presence || 'RUB'}"
            end
            column('SKU') do |row|
              skus = row.external_order_items.map(&:sku).compact.uniq
              skus.presence&.join(', ') || '—'
            end
          end
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
end
