# frozen_string_literal: true

class CreateInsalesMediaStatusItems < ActiveRecord::Migration[8.0]
  def change
    create_table :insales_media_status_items do |t|
      t.uuid :product_id, null: false
      t.string :kind, null: false
      t.string :source_key, null: false
      t.string :source_checksum
      t.text :source_url
      t.boolean :api_ok, null: false, default: false
      t.datetime :api_verified_at
      t.text :api_error
      t.boolean :storefront_ok, null: false, default: false
      t.datetime :storefront_verified_at
      t.text :storefront_error
      t.string :status, null: false, default: 'in_progress'
      t.timestamps
    end

    add_index :insales_media_status_items, :product_id
    add_index :insales_media_status_items, [:product_id, :source_key], unique: true, name: 'index_insales_media_status_items_on_product_and_source'
  end
end
