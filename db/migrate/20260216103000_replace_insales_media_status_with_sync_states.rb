# frozen_string_literal: true

class ReplaceInsalesMediaStatusWithSyncStates < ActiveRecord::Migration[8.0]
  def change
    drop_table :insales_media_status_items, if_exists: true
    drop_table :insales_media_statuses, if_exists: true

    create_table :insales_media_sync_states do |t|
      t.uuid :product_id, null: false
      t.integer :insales_product_id
      t.integer :photos_in_aura, null: false, default: 0
      t.integer :photos_uploaded, null: false, default: 0
      t.boolean :verified_admin, null: false, default: false
      t.boolean :verified_storefront, null: false, default: false
      t.string :status, null: false, default: 'in_progress'
      t.text :last_error
      t.datetime :synced_at
      t.timestamps
    end

    add_index :insales_media_sync_states, :product_id, unique: true
  end
end
