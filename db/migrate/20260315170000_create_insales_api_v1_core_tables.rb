# frozen_string_literal: true

class CreateInsalesApiV1CoreTables < ActiveRecord::Migration[8.0]
  def change
    create_table :sync_idempotency_keys, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :idempotency_key, null: false
      t.string :request_hash, null: false
      t.integer :response_status
      t.jsonb :response_body, null: false, default: {}
      t.datetime :expires_at
      t.timestamps
    end

    add_index :sync_idempotency_keys, :idempotency_key, unique: true
    add_index :sync_idempotency_keys, :expires_at

    create_table :sync_outbox_events, id: :bigserial do |t|
      t.uuid :event_id, null: false, default: -> { "gen_random_uuid()" }
      t.string :aggregate_type, null: false
      t.string :aggregate_id, null: false
      t.string :event_type, null: false
      t.jsonb :payload, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.datetime :processed_at
      t.integer :attempts, null: false, default: 0
      t.datetime :next_retry_at
      t.text :last_error
      t.timestamps
    end

    add_index :sync_outbox_events, :event_id, unique: true
    add_index :sync_outbox_events, :occurred_at
    add_index :sync_outbox_events, :processed_at
    add_index :sync_outbox_events, :event_type
    add_index :sync_outbox_events, %i[processed_at next_retry_at], name: 'index_sync_outbox_events_for_delivery'
    add_index :sync_outbox_events, %i[aggregate_type aggregate_id], name: 'index_sync_outbox_events_on_aggregate'

    create_table :insales_api_sync_runs, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :run_type, null: false
      t.string :status, null: false, default: 'queued'
      t.string :source
      t.string :batch_id
      t.string :idempotency_key
      t.integer :total_items, null: false, default: 0
      t.integer :processed, null: false, default: 0
      t.integer :created_count, null: false, default: 0
      t.integer :updated_count, null: false, default: 0
      t.integer :unchanged_count, null: false, default: 0
      t.integer :skipped_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.jsonb :errors, null: false, default: []
      t.jsonb :meta, null: false, default: {}
      t.datetime :started_at
      t.datetime :finished_at
      t.text :last_error
      t.timestamps
    end

    add_index :insales_api_sync_runs, :run_type
    add_index :insales_api_sync_runs, :status
    add_index :insales_api_sync_runs, :batch_id
    add_index :insales_api_sync_runs, :idempotency_key
  end
end
