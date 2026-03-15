# frozen_string_literal: true

class CreateExternalOrdersPipelineTables < ActiveRecord::Migration[8.0]
  def change
    create_table :external_orders, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :source, null: false
      t.string :external_order_id, null: false
      t.string :external_order_number
      t.string :status, null: false, default: 'received'
      t.string :payment_status
      t.bigint :total_minor
      t.string :currency, null: false, default: 'RUB'
      t.jsonb :payload_raw, null: false, default: {}
      t.datetime :last_event_at
      t.datetime :processed_at
      t.timestamps
    end

    add_index :external_orders, %i[source external_order_id], unique: true, name: 'idx_external_orders_source_order'
    add_index :external_orders, %i[status payment_status]
    add_index :external_orders, :last_event_at

    create_table :external_order_items, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :external_order, null: false, foreign_key: true, type: :uuid
      t.string :sku, null: false
      t.references :product, null: true, foreign_key: true, type: :uuid
      t.decimal :quantity, null: false, precision: 12, scale: 3, default: 0
      t.bigint :unit_price_minor
      t.string :currency, null: false, default: 'RUB'
      t.jsonb :meta, null: false, default: {}
      t.timestamps
    end

    add_index :external_order_items, :sku

    create_table :external_order_events, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :source, null: false
      t.string :source_event_id, null: false
      t.references :external_order, null: true, foreign_key: true, type: :uuid
      t.string :event_type
      t.datetime :event_at
      t.jsonb :payload_raw, null: false, default: {}
      t.string :processing_status, null: false, default: 'received'
      t.text :processing_error
      t.datetime :processed_at
      t.timestamps
    end

    add_index :external_order_events, %i[source source_event_id], unique: true, name: 'idx_external_order_events_source_event'
    add_index :external_order_events, %i[processing_status created_at], name: 'idx_external_order_events_processing'

    create_table :external_fulfillment_operations, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :external_order, null: false, foreign_key: true, type: :uuid
      t.string :operation_type, null: false, default: 'write_off'
      t.string :status, null: false, default: 'queued'
      t.string :ms_document_id
      t.string :comment
      t.integer :attempts, null: false, default: 0
      t.datetime :next_retry_at
      t.text :last_error
      t.string :idempotency_key, null: false
      t.timestamps
    end

    add_index :external_fulfillment_operations, :idempotency_key, unique: true
    add_index :external_fulfillment_operations, %i[status next_retry_at], name: 'idx_external_fulfillment_status_retry'
  end
end
