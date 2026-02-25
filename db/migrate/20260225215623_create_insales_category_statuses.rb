# frozen_string_literal: true

class CreateInsalesCategoryStatuses < ActiveRecord::Migration[8.0]
  def change
    create_table :insales_category_statuses do |t|
      t.string :aura_path, null: false
      t.bigint :insales_collection_id
      t.string :insales_collection_title
      t.bigint :insales_parent_collection_id
      t.string :sync_status, null: false, default: 'pending'
      t.text :last_error
      t.datetime :synced_at

      t.timestamps
    end

    add_index :insales_category_statuses, :aura_path, unique: true
  end
end
