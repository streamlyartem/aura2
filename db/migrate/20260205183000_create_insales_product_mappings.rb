# frozen_string_literal: true

class CreateInsalesProductMappings < ActiveRecord::Migration[8.0]
  def change
    create_table :insales_product_mappings, id: :uuid do |t|
      t.uuid :aura_product_id, null: false
      t.string :insales_product_id, null: false

      t.timestamps
    end

    add_index :insales_product_mappings, :aura_product_id, unique: true
    add_index :insales_product_mappings, :insales_product_id, unique: true
    add_foreign_key :insales_product_mappings, :products, column: :aura_product_id
  end
end
