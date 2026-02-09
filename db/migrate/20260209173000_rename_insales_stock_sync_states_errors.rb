# frozen_string_literal: true

class RenameInsalesStockSyncStatesErrors < ActiveRecord::Migration[8.0]
  def change
    return unless column_exists?(:insales_stock_sync_states, :errors)
    return if column_exists?(:insales_stock_sync_states, :error_count)

    rename_column :insales_stock_sync_states, :errors, :error_count
  end
end
