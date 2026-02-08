# frozen_string_literal: true

class CreateImages < ActiveRecord::Migration[8.0]
  def change
    create_table :images, id: :uuid do |t|
      t.references :object, polymorphic: true, type: :uuid, null: true

      t.timestamps
    end
  end
end
