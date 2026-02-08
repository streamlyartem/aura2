# frozen_string_literal: true

class CreateInsalesImageMappings < ActiveRecord::Migration[8.0]
  def change
    create_table :insales_image_mappings, id: :uuid do |t|
      t.uuid :aura_image_id, null: false
      t.string :insales_image_id, null: false
      t.string :insales_product_id, null: false

      t.timestamps
    end

    add_index :insales_image_mappings, :aura_image_id, unique: true
    add_index :insales_image_mappings, :insales_image_id, unique: true
    add_index :insales_image_mappings, :insales_product_id
    add_foreign_key :insales_image_mappings, :images, column: :aura_image_id
  end
end
