class AddPricingCoreV1 < ActiveRecord::Migration[8.0]
  def change
    create_table :price_types do |t|
      t.string :code, null: false
      t.string :ms_price_type_id
      t.string :currency, null: false, default: 'RUB'

      t.timestamps
    end
    add_index :price_types, :code, unique: true

    create_table :variant_prices, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :variant_id, null: false
      t.references :price_type, null: false, foreign_key: true
      t.integer :price_per_g_cents
      t.integer :price_per_piece_cents

      t.timestamps
    end
    add_index :variant_prices, %i[variant_id price_type_id], unique: true
    add_foreign_key :variant_prices, :products, column: :variant_id

    create_table :pricing_rulesets, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :channel, null: false
      t.string :name, null: false
      t.boolean :is_active, null: false, default: true

      t.timestamps
    end
    add_index :pricing_rulesets, %i[channel is_active]

    create_table :pricing_tiers, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :pricing_ruleset, null: false, type: :uuid, foreign_key: true
      t.integer :min_eligible_weight_g, null: false
      t.integer :max_eligible_weight_g
      t.string :price_type_code, null: false
      t.integer :priority, null: false, default: 0

      t.timestamps
    end
    add_index :pricing_tiers, %i[pricing_ruleset_id priority]

    add_column :products, :unit_type, :string, null: false, default: 'weight'
    add_column :products, :unit_weight_g, :decimal, precision: 10, scale: 3
    add_column :products, :ms_stock_g, :integer
    add_column :products, :ms_stock_qty, :integer
  end
end
