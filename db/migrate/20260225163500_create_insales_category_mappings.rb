# frozen_string_literal: true

class CreateInsalesCategoryMappings < ActiveRecord::Migration[8.0]
  def change
    create_table :insales_category_mappings do |t|
      t.string :product_type, null: false
      t.string :tone
      t.integer :length
      t.boolean :ombre
      t.string :structure
      t.bigint :insales_category_id, null: false

      t.timestamps
    end

    add_index :insales_category_mappings,
              %i[product_type tone length ombre structure],
              unique: true,
              name: 'index_insales_category_mappings_on_key'
  end
end
