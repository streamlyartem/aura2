# frozen_string_literal: true

ActiveAdmin.register_page 'InSales Media Status' do
  menu label: 'InSales Media Status', priority: 7

  page_action :recheck, method: :post do
    product_id = params[:product_id]
    product = Product.find_by(id: product_id)
    if product
      Insales::VerifyMediaVisibilityJob.perform_later(product_id: product.id)
      redirect_to admin_insales_media_status_path(product_id: product.id), notice: 'Проверка медиа запущена. Обновите страницу через несколько секунд.'
    else
      redirect_to admin_insales_media_status_path, alert: 'Товар не найден.'
    end
  end

  content title: 'InSales Media Status' do
    if params[:product_id].present?
      product = Product.find_by(id: params[:product_id])
      status = InsalesMediaStatus.find_by(product_id: product&.id)
      items = InsalesMediaStatusItem.where(product_id: product&.id).order(:kind, :source_key)

      panel 'Статус медиа товара' do
        if product.nil?
          para 'Товар не найден.'
        else
          table_for [
            ['Product ID', product.id],
            ['Name', product.name],
            ['SKU', product.sku],
            ['Photos', product.images.select(&:image?).count],
            ['Videos', product.images.select(&:video?).count],
            ['Status', status&.status || '—'],
            ['Last checked', status&.last_checked_at || '—'],
            ['Last API verified', status&.last_api_verified_at || '—'],
            ['Last storefront verified', status&.last_storefront_verified_at || '—'],
            ['Last error', status&.last_error || '—']
          ] do
            column('Metric') { |row| row[0] }
            column('Value') { |row| row[1] }
          end

          div class: 'mt-3' do
            form action: admin_insales_media_status_recheck_path, method: :post do
              input type: 'hidden', name: 'authenticity_token', value: form_authenticity_token
              input type: 'hidden', name: 'product_id', value: product.id
              input type: 'submit', value: 'Recheck', class: 'button'
            end
          end
        end
      end

      panel 'Items' do
        if items.empty?
          para 'Нет элементов для отображения.'
        else
          table_for items do
            column('Kind', &:kind)
            column('Source') { |item| item.source_key }
            column('API ok') { |item| item.api_ok }
            column('API verified at') { |item| item.api_verified_at || '—' }
            column('API error') { |item| item.api_error || '—' }
            column('Storefront ok') { |item| item.storefront_ok }
            column('Storefront verified at') { |item| item.storefront_verified_at || '—' }
            column('Storefront error') { |item| item.storefront_error || '—' }
            column('Status') { |item| item.status }
          end
        end
      end
    else
      products = Product.includes(:images).order(created_at: :desc).page(params[:page]).per(25)
      statuses = InsalesMediaStatus.where(product_id: products.map(&:id)).index_by(&:product_id)

      panel 'Media status by product' do
        paginated_collection(products, download_links: false) do
          table_for products do
            column('Id', &:id)
            column('Name') { |product| product.name }
            column('SKU') { |product| product.sku }
            column('Photos') { |product| product.images.select(&:image?).count }
            column('Videos') { |product| product.images.select(&:video?).count }
            column('Status') { |product| statuses[product.id]&.status || '—' }
            column('Action') do |product|
              link_to 'View', admin_insales_media_status_path(product_id: product.id)
            end
          end
        end
      end
    end
  end
end
