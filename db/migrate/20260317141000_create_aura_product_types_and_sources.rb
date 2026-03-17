# frozen_string_literal: true

class CreateAuraProductTypesAndSources < ActiveRecord::Migration[8.0]
  def change
    create_table :aura_product_types, id: :uuid do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.string :matcher_path_prefix
      t.string :matcher_unit_type
      t.boolean :weight_from_stock, null: false, default: false
      t.boolean :active, null: false, default: true
      t.integer :priority, null: false, default: 100

      t.timestamps
    end

    add_index :aura_product_types, :code, unique: true
    add_index :aura_product_types, %i[active priority]

    create_table :aura_product_sources, id: :uuid do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :source_kind, null: false, default: 'moysklad'
      t.boolean :active, null: false, default: true
      t.integer :priority, null: false, default: 100
      t.boolean :authoritative, null: false, default: false
      t.jsonb :settings, null: false, default: {}

      t.timestamps
    end

    add_index :aura_product_sources, :code, unique: true
    add_index :aura_product_sources, %i[active priority]

    reversible do |dir|
      dir.up do
        execute <<~SQL
          INSERT INTO aura_product_sources (code, name, source_kind, active, priority, authoritative, settings, created_at, updated_at)
          VALUES ('moysklad', 'МойСклад', 'moysklad', TRUE, 10, TRUE, '{}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          ON CONFLICT (code) DO NOTHING;
        SQL

        execute <<~SQL
          INSERT INTO aura_product_types (code, name, description, matcher_unit_type, weight_from_stock, active, priority, created_at, updated_at)
          VALUES
            ('weight', 'Весовые товары', 'Товары с весовыми характеристиками.', NULL, FALSE, TRUE, 10, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
            ('piece', 'Штучные товары', 'Товары, продаваемые поштучно.', NULL, FALSE, TRUE, 20, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          ON CONFLICT (code) DO NOTHING;
        SQL
      end
    end
  end
end
