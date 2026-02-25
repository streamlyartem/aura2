# frozen_string_literal: true

class AddStructureToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :structure, :string
  end
end
