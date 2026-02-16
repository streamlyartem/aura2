# frozen_string_literal: true

class CreateInsalesMediaStatuses < ActiveRecord::Migration[8.0]
  def change
    create_table :insales_media_statuses do |t|
      t.uuid :product_id, null: false
      t.integer :photos_count, null: false, default: 0
      t.integer :videos_count, null: false, default: 0
      t.string :status, null: false, default: 'in_progress'
      t.text :last_error
      t.datetime :last_checked_at
      t.datetime :last_api_verified_at
      t.datetime :last_storefront_verified_at
      t.timestamps
    end

    add_index :insales_media_statuses, :product_id, unique: true
  end
end
