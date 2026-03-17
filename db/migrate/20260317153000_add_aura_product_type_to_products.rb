# frozen_string_literal: true

class AddAuraProductTypeToProducts < ActiveRecord::Migration[8.0]
  def change
    add_reference :products, :aura_product_type, type: :uuid, foreign_key: true, index: true
  end
end
