class AddFieldsToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :batch_number, :string
    add_column :products, :path_name, :string
    add_column :products, :weight, :decimal, precision: 10, scale: 2
    add_column :products, :length, :decimal, precision: 10, scale: 2
    add_column :products, :color, :string
    add_column :products, :tone, :string
    add_column :products, :ombre, :boolean, null: false, default: false
    add_column :products, :code, :string
    add_column :products, :barcodes, :jsonb, default: []
    add_column :products, :purchase_price, :decimal, precision: 10, scale: 2
    add_column :products, :retail_price, :decimal, precision: 10, scale: 2
    add_column :products, :small_wholesale_price, :decimal, precision: 10, scale: 2
    add_column :products, :large_wholesale_price, :decimal, precision: 10, scale: 2
    add_column :products, :five_hundred_plus_wholesale_price, :decimal, precision: 10, scale: 2
    add_column :products, :min_price, :decimal, precision: 10, scale: 2
  end
end
