# frozen_string_literal: true

class AddStatusToInsalesSyncRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :insales_sync_runs, :status, :string, null: false, default: 'running'
  end
end
