# frozen_string_literal: true

class AddErrorDetailsToInsalesSyncRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :insales_sync_runs, :error_details, :text
    add_column :insales_sync_runs, :status, :string, null: false, default: 'running'
  end
end
