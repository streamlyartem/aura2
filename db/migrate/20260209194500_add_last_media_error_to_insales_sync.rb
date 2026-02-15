# frozen_string_literal: true

class AddLastMediaErrorToInsalesSync < ActiveRecord::Migration[8.0]
  def change
    add_column :insales_sync_runs, :last_media_error, :text
    add_column :insales_stock_sync_states, :last_media_error, :text
  end
end
