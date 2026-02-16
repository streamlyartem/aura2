# frozen_string_literal: true

class DropInsalesMediaItemsTables < ActiveRecord::Migration[8.0]
  def change
    drop_table :insales_media_mappings, if_exists: true
    drop_table :insales_media_items, if_exists: true
  end
end
