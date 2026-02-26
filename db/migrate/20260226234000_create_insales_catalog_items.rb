# frozen_string_literal: true

class CreateInsalesCatalogItems < ActiveRecord::Migration[8.0]
  def change
    create_table :insales_catalog_items, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :product_id, null: false
      t.integer :export_quantity
      t.jsonb :prices_cents, null: false, default: {}
      t.string :status, null: false, default: 'ready'
      t.string :skip_reason
      t.datetime :prepared_at
      t.text :last_error

      t.timestamps
    end

    add_index :insales_catalog_items, :product_id, unique: true
    add_index :insales_catalog_items, :status
  end
end
