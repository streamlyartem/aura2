# frozen_string_literal: true

class CreateInsalesStockSyncStates < ActiveRecord::Migration[8.0]
  def change
    create_table :insales_stock_sync_states, id: :uuid do |t|
      t.string :store_name, null: false
      t.datetime :last_stock_sync_at
      t.datetime :last_run_at
      t.string :last_status
      t.integer :processed
      t.integer :created
      t.integer :updated
      t.integer :errors
      t.integer :variants_updated
      t.text :last_error
      t.timestamps
    end

    add_index :insales_stock_sync_states, :store_name, unique: true
  end
end
