# frozen_string_literal: true

ActiveAdmin.register_page 'MoySklad Stores' do
  menu label: 'Склады МС', parent: 'МойСклад', priority: 3,
       if: proc { current_admin_user&.can_access_admin_path?('/admin/moysklad_stores') }

  action_item :refresh_stores, only: :index do
    link_to '↻ Обновить список',
            admin_moysklad_stores_refresh_path,
            method: :post,
            class: 'button'
  end

  page_action :refresh, method: :post do
    names = MoyskladStore.refresh_from_moysklad!
    MoyskladStore.enqueue_stock_counts_refresh!(store_names: names)
    redirect_to admin_moysklad_stores_path,
                notice: "Список складов обновлён: #{names.size}. Пересчёт остатков запущен в фоне."
  rescue StandardError => e
    redirect_to admin_moysklad_stores_path, alert: "Не удалось обновить список складов: #{e.class} - #{e.message}"
  end

  page_action :apply_selection, method: :post do
    selected_ids = Array(params[:selected_store_ids]).map(&:to_s).uniq

    MoyskladStore.update_all(selected_for_import: false)
    MoyskladStore.where(id: selected_ids).update_all(selected_for_import: true) if selected_ids.any?

    redirect_to admin_moysklad_stores_path, notice: 'Выбор складов сохранён'
  end

  content title: 'Склады МС' do
    stores = MoyskladStore.order(:name).to_a
    selected_count = stores.count(&:selected_for_import?)
    stores_with_counts = stores.select { |store| store.total_products_count.present? && store.nonzero_products_count.present? }
    total_products = stores_with_counts.sum(&:total_products_count)
    nonzero_products = stores_with_counts.sum(&:nonzero_products_count)
    zero_or_negative_products = total_products - nonzero_products
    last_stock_stats_update = stores_with_counts.map(&:stock_stats_synced_at).compact.max

    div class: 'mb-4' do
      span "Всего складов: #{stores.size}. Выбрано для импорта: #{selected_count}."
    end

    panel 'Сводка по остаткам' do
      table_for(
        [
          ['Всего товаров по складам', total_products],
          ['Всего товаров с нулевыми остатками', zero_or_negative_products],
          ['Последнее обновление', last_stock_stats_update || '—']
        ]
      ) do
        column('Показатель') { |row| row.first }
        column('Значение') { |row| row.last }
      end
    end

    form action: url_for(action: :apply_selection), method: :post do
      input type: 'hidden', name: 'authenticity_token', value: form_authenticity_token

      table_for stores do
        column 'Выбрать' do |store|
          if store.selected_for_import?
            input type: 'checkbox',
                  name: 'selected_store_ids[]',
                  value: store.id,
                  checked: 'checked'
          else
            input type: 'checkbox',
                  name: 'selected_store_ids[]',
                  value: store.id
          end
        end
        column('Склад') { |store| store.name }
        column('Товаров всего') { |store| store.total_products_count || '—' }
        column('Товаров с ненулевым остатком') { |store| store.nonzero_products_count || '—' }
        column('Обновлено по остаткам') { |store| store.stock_stats_synced_at || '—' }
      end

      div class: 'mt-4' do
        a href: '#',
          class: 'button primary',
          onclick: 'this.closest("form").submit(); return false;' do
          text_node 'Применить'
        end
      end
    end
  end
end
