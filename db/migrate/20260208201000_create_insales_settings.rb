# frozen_string_literal: true

class CreateInsalesSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :insales_settings, id: :uuid do |t|
      t.string :login, null: false
      t.string :password, null: false
      t.string :base_url, null: false
      t.string :category_id, null: false
      t.string :image_url_mode, null: false, default: 'service_url'

      t.timestamps
    end
  end
end
