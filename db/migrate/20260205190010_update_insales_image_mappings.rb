# frozen_string_literal: true

class UpdateInsalesImageMappings < ActiveRecord::Migration[8.0]
  def change
    change_column :insales_image_mappings, :insales_product_id, :bigint,
                  using: 'insales_product_id::bigint'
    change_column :insales_image_mappings, :insales_image_id, :bigint, null: true,
                  using: 'insales_image_id::bigint'
    add_column :insales_image_mappings, :src_hash, :string
    add_column :insales_image_mappings, :last_synced_at, :datetime
  end
end
