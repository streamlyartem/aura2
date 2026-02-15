# frozen_string_literal: true

class AddInsalesSyncMetrics < ActiveRecord::Migration[8.0]
  def change
    change_table :insales_sync_runs, bulk: true do |t|
      t.integer :images_uploaded, default: 0, null: false
      t.integer :images_skipped, default: 0, null: false
      t.integer :images_errors, default: 0, null: false
      t.integer :videos_uploaded, default: 0, null: false
      t.integer :videos_skipped, default: 0, null: false
      t.integer :verify_failures, default: 0, null: false
      t.integer :last_http_status
      t.string :last_http_endpoint
      t.datetime :last_verified_at
      t.string :last_error
    end

    change_table :insales_stock_sync_states, bulk: true do |t|
      t.integer :images_uploaded, default: 0, null: false
      t.integer :images_skipped, default: 0, null: false
      t.integer :images_errors, default: 0, null: false
      t.integer :videos_uploaded, default: 0, null: false
      t.integer :videos_skipped, default: 0, null: false
      t.integer :verify_failures, default: 0, null: false
      t.integer :last_http_status
      t.string :last_http_endpoint
      t.datetime :last_verified_at
    end
  end
end
