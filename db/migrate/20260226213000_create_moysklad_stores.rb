# frozen_string_literal: true

class CreateMoyskladStores < ActiveRecord::Migration[8.0]
  def change
    create_table :moysklad_stores, id: :uuid do |t|
      t.string :name, null: false
      t.boolean :selected_for_import, null: false, default: false
      t.datetime :last_seen_at

      t.timestamps
    end

    add_index :moysklad_stores, :name, unique: true
    add_index :moysklad_stores, :selected_for_import
  end
end
