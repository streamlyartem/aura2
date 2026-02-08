# frozen_string_literal: true

class AddDefaultCollectionIdToInsalesSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :insales_settings, :default_collection_id, :bigint
  end
end
