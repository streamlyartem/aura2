# frozen_string_literal: true

class CreateInsalesMediaItems < ActiveRecord::Migration[8.0]
  def change
    create_table :insales_media_items, id: :uuid do |t|
      t.uuid :aura_product_id, null: false
      t.string :kind, null: false
      t.string :source_type, null: false, default: 'image'
      t.uuid :aura_image_id
      t.string :url
      t.integer :position, null: false, default: 1
      t.boolean :export_to_insales, null: false, default: true
      t.string :checksum
      t.timestamps
    end

    add_index :insales_media_items, [:aura_product_id, :kind, :position], unique: true, name: 'index_insales_media_items_on_product_kind_position'
    add_index :insales_media_items, :aura_product_id
  end
end
