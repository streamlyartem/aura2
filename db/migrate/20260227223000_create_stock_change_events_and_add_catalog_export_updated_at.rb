class CreateStockChangeEventsAndAddCatalogExportUpdatedAt < ActiveRecord::Migration[8.0]
  def change
    create_table :stock_change_events, id: :uuid do |t|
      t.references :product, null: false, type: :uuid, foreign_key: true, index: { unique: true }
      t.string :priority, null: false, default: "normal"
      t.string :reason, null: false, default: "stock_changed"
      t.datetime :event_updated_at, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :locked_at
      t.string :locked_by
      t.integer :attempts, null: false, default: 0
      t.datetime :next_retry_at
      t.text :last_error
      t.timestamps
    end

    add_index :stock_change_events, [:priority, :status, :next_retry_at], name: "index_stock_change_events_on_priority_status_retry"
    add_index :stock_change_events, [:status, :locked_at]

    add_column :insales_catalog_items, :export_updated_at, :datetime
    add_index :insales_catalog_items, :export_updated_at
  end
end
