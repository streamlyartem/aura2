# frozen_string_literal: true

require 'erb'

ActiveAdmin.register_page 'InSales Media Status' do
  menu parent: 'InSales', label: 'InSales Media Status', priority: 5

  content title: 'InSales Media Status' do
    if params[:product_id].present?
      product = Product.find_by(id: params[:product_id])
      state = InsalesMediaSyncState.find_by(product_id: product&.id)
      storefront_url = if product&.path_name.present?
                          base = InsalesSetting.first&.base_url || ENV['INSALES_BASE_URL']
                          base = "https://#{base}" if base.present? && !base.start_with?('http')
                          if base.present?
                            escaped_path = product.path_name.to_s.split('/').map { |seg| ERB::Util.url_encode(seg) }.join('/')
                            URI.join("#{base}/", "product/#{escaped_path}").to_s
                          end
                        end

      panel 'Product media status' do
        if product.nil?
          para 'Product not found.'
        else
          table_for [
            ['Product ID', product.id],
            ['Name', product.name],
            ['SKU', product.sku],
            ['InSales product id', state&.insales_product_id || '—'],
            ['Photos in AURA', state&.photos_in_aura || product.images.select(&:image?).count],
            ['Photos uploaded', state&.photos_uploaded || '—'],
            ['Verified admin', state&.verified_admin || false],
            ['Verified storefront', state&.verified_storefront || false],
            ['Status', state&.status || '—'],
            ['Last error', state&.last_error || '—'],
            ['Synced at', state&.synced_at || '—']
          ] do
            column('Metric') { |row| row[0] }
            column('Value') { |row| row[1] }
          end

          if storefront_url.present?
            div do
              para link_to('Public product page', storefront_url, target: '_blank', rel: 'noopener')
            end
          end
        end
      end
    else
      store_names = ProductStock.distinct.order(:store_name).pluck(:store_name)
      preferred_store = params[:store_name].presence || 'Тест'
      store_name = store_names.include?(preferred_store) ? preferred_store : store_names.first
      product_ids = if store_name
                      ProductStock.where(store_name: store_name).distinct.pluck(:product_id)
                    else
                      []
                    end

      products = Product.where(id: product_ids).includes(:images).order(created_at: :desc).page(params[:page]).per(25)
      states = InsalesMediaSyncState.where(product_id: products.map(&:id)).index_by(&:product_id)

      panel 'Media status by product' do
        div class: 'mb-4' do
          form action: admin_insales_media_status_path, method: :get do
            label 'Склад'
            select name: 'store_name' do
              store_names.each do |name|
                option name, value: name, selected: name == store_name
              end
            end
            div class: 'mt-3' do
              input type: 'submit', value: 'Показать', class: 'button'
            end
          end
        end

        paginated_collection(products, download_links: false) do
          table_for products do
            column('Id', &:id)
            column('Name') { |product| product.name }
            column('SKU') { |product| product.sku }
            column('Photos') { |product| product.images.select(&:image?).count }
            column('Videos') { |_product| 0 }
            column('Status') { |product| states[product.id]&.status || '—' }
            column('View') do |product|
              link_to 'View', admin_insales_media_status_path(product_id: product.id)
            end
          end
        end
      end
    end
  end
end
