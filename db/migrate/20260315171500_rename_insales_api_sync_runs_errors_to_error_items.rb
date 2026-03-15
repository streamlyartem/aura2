# frozen_string_literal: true

class RenameInsalesApiSyncRunsErrorsToErrorItems < ActiveRecord::Migration[8.0]
  def change
    return unless column_exists?(:insales_api_sync_runs, :errors)

    rename_column :insales_api_sync_runs, :errors, :error_items
  end
end
