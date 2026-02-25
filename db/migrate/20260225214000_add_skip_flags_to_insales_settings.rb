# frozen_string_literal: true

class AddSkipFlagsToInsalesSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :insales_settings, :skip_products_without_sku, :boolean, null: false, default: false
    add_column :insales_settings, :skip_products_with_nonpositive_stock, :boolean, null: false, default: false
  end
end
