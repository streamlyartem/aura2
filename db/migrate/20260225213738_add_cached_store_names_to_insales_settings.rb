# frozen_string_literal: true

class AddCachedStoreNamesToInsalesSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :insales_settings, :cached_store_names, :jsonb, null: false, default: []
    add_column :insales_settings, :cached_store_names_synced_at, :datetime
  end
end
