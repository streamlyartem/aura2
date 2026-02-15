# frozen_string_literal: true

class CreateInsalesMediaMappings < ActiveRecord::Migration[8.0]
  def change
    create_table :insales_media_mappings, id: :uuid do |t|
      t.uuid :aura_media_item_id, null: false
      t.bigint :insales_product_id, null: false
      t.bigint :insales_media_id
      t.string :kind, null: false
      t.integer :position
      t.string :last_synced_checksum
      t.datetime :last_synced_at
      t.timestamps
    end

    add_index :insales_media_mappings, :aura_media_item_id, unique: true
    add_index :insales_media_mappings, [:insales_product_id, :kind]
  end
end
