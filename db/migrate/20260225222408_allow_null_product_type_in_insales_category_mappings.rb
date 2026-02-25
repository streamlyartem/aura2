# frozen_string_literal: true

class AllowNullProductTypeInInsalesCategoryMappings < ActiveRecord::Migration[8.0]
  def change
    change_column_null :insales_category_mappings, :product_type, true
  end
end
