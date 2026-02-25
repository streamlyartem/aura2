# frozen_string_literal: true

ActiveAdmin.register_page 'InSales Category Status' do
  menu label: 'InSales Category Status', priority: 8

  content title: 'InSales Category Status' do
    last_run = InsalesCategorySyncRun.order(created_at: :desc).first

    panel 'Category Sync' do
      div class: 'mb-4' do
        form action: url_for(action: :sync_categories), method: :post do
          input type: 'hidden', name: 'authenticity_token', value: form_authenticity_token
          input type: 'submit', value: 'Синхронизировать категории', class: 'button'
        end
      end

      table_for [
        ['Last sync run', last_run&.finished_at || '—'],
        ['Status', last_run&.status || '—'],
        ['Processed', last_run&.processed || '—'],
        ['Created', last_run&.created || '—'],
        ['Updated', last_run&.updated || '—'],
        ['Errors', last_run&.error_count || '—'],
        ['Last error', last_run&.last_error.presence || '—']
      ] do
        column('Metric') { |row| row[0] }
        column('Value') { |row| row[1] }
      end
    end

    mappings = InsalesCategoryMapping.all.to_a
    resolver = Insales::CategoryMappingResolver.new(mappings)

    totals = Hash.new { |h, k| h[k] = { total: 0, mapped: 0, unmapped: 0 } }
    unmapped_samples = []

    Product.select(:id, :name, :sku, :path_name, :tone, :length, :ombre, :structure).find_each do |product|
      product_type = product.path_name.to_s.split('/').first
      next if product_type.blank?

      totals[product_type][:total] += 1
      if resolver.category_id_for(product).present?
        totals[product_type][:mapped] += 1
      else
        totals[product_type][:unmapped] += 1
        if unmapped_samples.size < 20
          unmapped_samples << product
        end
      end
    end

    panel 'Summary by Type' do
      table_for totals.sort_by { |type, _| type.to_s } do
        column('Type') { |row| row[0] }
        column('Total') { |row| row[1][:total] }
        column('Mapped') { |row| row[1][:mapped] }
        column('Unmapped') { |row| row[1][:unmapped] }
      end
    end

    panel 'Unmapped Samples (first 20)' do
      if unmapped_samples.empty?
        div 'All products have category mappings.'
      else
        table_for unmapped_samples do
          column :id
          column :name
          column :sku
          column :path_name
          column :tone
          column :length
          column :ombre
          column :structure
        end
      end
    end
  end

  page_action :sync_categories, method: :post do
    Insales::SyncCategoryMappingsJob.perform_later
    redirect_to admin_insales_category_status_path, notice: 'Запущена синхронизация категорий InSales'
  end
end
