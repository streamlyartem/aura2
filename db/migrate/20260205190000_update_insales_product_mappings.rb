# frozen_string_literal: true

class UpdateInsalesProductMappings < ActiveRecord::Migration[8.0]
  def change
    change_column :insales_product_mappings, :insales_product_id, :bigint,
                  using: 'insales_product_id::bigint'
    add_column :insales_product_mappings, :payload_hash, :string
    add_column :insales_product_mappings, :last_synced_at, :datetime
  end
end
