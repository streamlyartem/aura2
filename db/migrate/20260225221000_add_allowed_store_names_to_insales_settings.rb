# frozen_string_literal: true

class AddAllowedStoreNamesToInsalesSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :insales_settings, :allowed_store_names, :jsonb, default: [], null: false
  end
end
