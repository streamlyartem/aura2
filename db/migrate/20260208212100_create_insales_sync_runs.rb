# frozen_string_literal: true

class CreateInsalesSyncRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :insales_sync_runs, id: :uuid do |t|
      t.string :store_name, null: false
      t.integer :total_products, default: 0, null: false
      t.integer :processed, default: 0, null: false
      t.integer :created, default: 0, null: false
      t.integer :updated, default: 0, null: false
      t.integer :errors, default: 0, null: false
      t.integer :variants_updated, default: 0, null: false
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :insales_sync_runs, :store_name
  end
end
