# frozen_string_literal: true

class AddPathMappingFieldsToInsalesCategoryMappings < ActiveRecord::Migration[8.0]
  def change
    add_column :insales_category_mappings, :aura_key, :string
    add_column :insales_category_mappings, :aura_key_type, :string
    add_column :insales_category_mappings, :insales_collection_title, :string
    add_column :insales_category_mappings, :comment, :string
    add_column :insales_category_mappings, :is_active, :boolean, null: false, default: true

    add_index :insales_category_mappings, [:aura_key_type, :aura_key], unique: true
    add_index :insales_category_mappings, :insales_category_id
  end
end
