# frozen_string_literal: true

class CreateInsalesCategorySyncRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :insales_category_sync_runs do |t|
      t.string :status, null: false, default: 'running'
      t.integer :processed
      t.integer :created
      t.integer :updated
      t.integer :error_count
      t.text :last_error
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end
  end
end
