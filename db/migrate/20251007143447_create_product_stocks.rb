class CreateProductStocks < ActiveRecord::Migration[8.0]
  def change
    create_table :product_stocks, id: :uuid do |t|
      t.references :product, null: false, foreign_key: true, type: :uuid
      t.string :store_name, null: false
      t.decimal :stock, precision: 10, scale: 2, default: 0.0
      t.decimal :free_stock, precision: 10, scale: 2, default: 0.0
      t.decimal :reserve, precision: 10, scale: 2, default: 0.0
      t.datetime :synced_at

      t.timestamps
    end
  end
end
