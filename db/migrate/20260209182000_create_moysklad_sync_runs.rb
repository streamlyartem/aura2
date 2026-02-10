# frozen_string_literal: true

class CreateMoyskladSyncRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :moysklad_sync_runs, id: :uuid do |t|
      t.string :run_type, null: false
      t.datetime :started_at
      t.datetime :finished_at
      t.string :status, null: false, default: 'running'
      t.integer :processed
      t.integer :created
      t.integer :updated
      t.integer :error_count
      t.text :last_error
      t.jsonb :meta
      t.timestamps
    end

    add_index :moysklad_sync_runs, :run_type
    add_index :moysklad_sync_runs, :started_at
  end
end
