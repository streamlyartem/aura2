# frozen_string_literal: true

class RenameInsalesSyncRunsErrors < ActiveRecord::Migration[8.0]
  def change
    rename_column :insales_sync_runs, :errors, :error_count
  end
end
