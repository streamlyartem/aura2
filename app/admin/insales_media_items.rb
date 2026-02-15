# frozen_string_literal: true

ActiveAdmin.register InsalesMediaItem do
  menu label: 'InSales Media Items', priority: 7

  permit_params :aura_product_id, :kind, :source_type, :aura_image_id, :url, :position, :export_to_insales

  index do
    selectable_column
    id_column
    column :aura_product_id
    column :kind
    column :source_type
    column :position
    column :export_to_insales
    column :updated_at
    actions
  end

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)

    f.inputs 'InSales Media Item' do
      f.input :aura_product_id, as: :select, collection: Product.order(:name).pluck(:name, :id)
      f.input :kind, as: :select, collection: InsalesMediaItem::KINDS, include_blank: false
      f.input :source_type, as: :select, collection: InsalesMediaItem::SOURCE_TYPES, include_blank: false
      f.input :aura_image_id, as: :select, collection: Image.order(created_at: :desc).limit(200).map { |img|
        label = "#{img.id} (#{img.object_type})"
        [label, img.id]
      }
      f.input :url
      f.input :position
      f.input :export_to_insales
    end

    f.actions
  end
end
