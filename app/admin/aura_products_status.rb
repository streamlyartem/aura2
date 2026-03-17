# frozen_string_literal: true

ActiveAdmin.register_page 'Aura Products Status' do
  menu label: 'Статус по товарам', parent: 'Товары AURA', priority: 1,
       if: proc { current_admin_user&.can_access_admin_path?('/admin/aura_products_status') }

  action_item :refresh_snapshot, only: :index do
    link_to '↻ Обновить статус', admin_aura_products_status_path(refresh: 1), class: 'button'
  end

  action_item :assign_types, only: :index do
    link_to 'Переразметить типы', admin_aura_products_status_assign_types_path, method: :post, class: 'button'
  end

  page_action :assign_types, method: :post do
    AuraProducts::AssignTypesJob.perform_later
    redirect_to admin_aura_products_status_path, notice: 'Запущена фоновая переразметка типов товаров.'
  end

  content title: 'Статус по товарам' do
    snapshot = AuraProducts::StatusSnapshot.call(force: params[:refresh].present?)

    panel 'Сводка' do
      table_for(
        [
          ['Всего товаров', snapshot[:total_products]],
          ['Товаров в стоках (все склады)', snapshot[:products_with_stock_rows]],
          ['Товаров в выбранных складах', snapshot[:products_on_selected_stores]],
          ['Товаров с остатком > 0 (выбранные склады)', snapshot[:products_with_positive_stock_on_selected_stores]],
          ['Размечено по типам', snapshot[:products_typed]],
          ['Неразмечено', snapshot[:products_untyped]],
          ['InSales каталог: ready', snapshot[:insales_catalog_ready]],
          ['InSales каталог: skipped', snapshot[:insales_catalog_skipped]],
          ['InSales каталог: error', snapshot[:insales_catalog_error]],
          ['Выбранные склады', snapshot[:selected_store_names].presence&.join(', ') || '—'],
          ['Обновлено', snapshot[:generated_at]]
        ]
      ) do
        column('Показатель') { |row| row.first }
        column('Значение') { |row| row.last }
      end
    end

    panel 'Распределение по типам' do
      rows = snapshot[:product_type_stats]
      if rows.empty?
        para 'Типы товаров ещё не настроены или нет совпадений по текущим правилам.'
      else
        table_for rows do
          column('Тип') { |row| row[:type].name }
          column('Код') { |row| row[:type].code }
          column('Товаров') { |row| row[:count] }
          column('Правило path') { |row| row[:type].matcher_path_prefix.presence || '—' }
          column('Правило unit_type') { |row| row[:type].matcher_unit_type.presence || '—' }
        end
      end
    end
  end
end
