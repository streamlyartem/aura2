# frozen_string_literal: true

ActiveAdmin.register_page 'MoySklad Stores' do
  menu label: 'Склады МС', parent: 'МойСклад', priority: 3

  page_action :refresh, method: :post do
    names = MoyskladStore.refresh_from_moysklad!
    redirect_to admin_moysklad_stores_path, notice: "Список складов обновлён: #{names.size}"
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

    div class: 'mb-4' do
      form action: url_for(action: :refresh), method: :post do
        input type: 'hidden', name: 'authenticity_token', value: form_authenticity_token
        input type: 'submit', value: 'Обновить список', class: 'button'
      end
    end

    div class: 'mb-4' do
      span "Всего складов: #{stores.size}. Выбрано для импорта: #{selected_count}."
    end

    form action: url_for(action: :apply_selection), method: :post do
      input type: 'hidden', name: 'authenticity_token', value: form_authenticity_token

      table_for stores do
        column 'Выбрать' do |store|
          input type: 'checkbox',
                name: 'selected_store_ids[]',
                value: store.id,
                checked: store.selected_for_import?
        end
        column('Склад') { |store| store.name }
        column('Обновлён') { |store| store.updated_at }
      end

      div class: 'mt-4' do
        input type: 'submit', value: 'Применить', class: 'button'
      end
    end
  end
end
