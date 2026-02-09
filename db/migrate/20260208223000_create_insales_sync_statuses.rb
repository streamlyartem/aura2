# frozen_string_literal: true

class CreateInsalesSyncStatuses < ActiveRecord::Migration[8.0]
  def change
    create_table :insales_sync_statuses, id: :uuid do |t|
      t.string :store_name, null: false
      t.datetime :last_stock_sync_at
      t.datetime :last_run_at
      t.integer :last_processed, default: 0, null: false
      t.integer :last_created, default: 0, null: false
      t.integer :last_updated, default: 0, null: false
      t.integer :last_error_count, default: 0, null: false
      t.jsonb :last_result_json

      t.timestamps
    end

    add_index :insales_sync_statuses, :store_name, unique: true
  end
end
