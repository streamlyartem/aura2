# frozen_string_literal: true

ActiveAdmin.register_page 'InSales Category Status' do
  menu label: 'InSales Category Status', priority: 8

  content title: 'InSales Category Status' do
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
end
