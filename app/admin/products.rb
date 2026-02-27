# frozen_string_literal: true

ActiveAdmin.register Product do
  menu label: 'Все товары из МС', parent: 'МойСклад', priority: 5,
       if: proc { current_admin_user&.can_access_admin_path?('/admin/products') }

  # Specify parameters which should be permitted for assignment
  permit_params images_attributes: %i[id file _destroy]

  action_item :scan_barcode, only: :index do
    link_to t('admin.products.actions.scan_barcode'), scan_admin_products_path
  end

  collection_action :scan, method: :get do
    render 'admin/products/scan'
  end

  collection_action :check_sku, method: :get do
    product = Product.find_by_scanned_barcode(params[:sku])

    if product
      render json: { exists: true, id: product.id, edit_url: edit_admin_product_path(product) }
    else
      render json: { exists: false }
    end
  end

  # For security, limit the actions that should be available
  actions :all, except: [:new]

  # Add or remove filters to toggle their visibility
  filter :id
  filter :ms_id
  filter :name
  filter :sku
  filter :created_at
  filter :updated_at

  # Add or remove columns to toggle their visibility in the index action
  index do
    selectable_column
    id_column
    column :name
    column :sku
    column :created_at
    column :updated_at
    actions
  end

  # Add or remove rows to toggle their visibility in the show action
  show do
    attributes_table_for(resource) do
      row :id
      row :ms_id
      row :name
      row :sku
      row :batch_number
      row :path_name
      row :weight
      row :length
      row :color
      row :tone
      row :ombre
      row :structure
      row :sku
      row :code
      row :barcodes
      row :purchase_price
      row :retail_price
      row :small_wholesale_price
      row :large_wholesale_price
      row :five_hundred_plus_wholesale_price
      row :min_price
      row :images do |product|
        if product.images.any?
          ul do
            product.images.each do |img|
              li do
                if img.video?
                  video_tag img.url, size: '300x300', controls: true
                elsif img.image?
                  image_tag img.url, size: '150x150'
                end
              end
            end
          end
        else
          status_tag t('admin.products.show.no_images')
        end
      end
      row :created_at
      row :updated_at
    end
  end

  # Add or remove fields to toggle their visibility in the form
  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)

    f.inputs t('admin.products.form.images_section') do
      f.has_many :images, allow_destroy: true, new_record: t('admin.products.form.add_image') do |ff|
        if ff.object&.persisted? && ff.object&.file&.attached? && ff.object.url
          hint_content = if ff.object.video?
                           video_tag(ff.object.url, size: '200x200', controls: true)
                         elsif ff.object.image?
                           image_tag(ff.object.url, size: '100x100')
                         end
          ff.input :file, as: :file, hint: hint_content
        else
          ff.input :file, as: :file
        end
      end
    end

    f.actions
  end
end
