# frozen_string_literal: true

class AddInsalesVariantIdToMappings < ActiveRecord::Migration[8.0]
  def change
    add_column :insales_product_mappings, :insales_variant_id, :bigint
    add_index :insales_product_mappings, :insales_variant_id
  end
end
