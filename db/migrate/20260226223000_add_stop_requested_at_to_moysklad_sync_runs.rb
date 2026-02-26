# frozen_string_literal: true

class AddStopRequestedAtToMoyskladSyncRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :moysklad_sync_runs, :stop_requested_at, :datetime
    add_index :moysklad_sync_runs, :stop_requested_at
  end
end
