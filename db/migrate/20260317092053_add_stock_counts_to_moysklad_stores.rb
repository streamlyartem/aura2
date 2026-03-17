class AddStockCountsToMoyskladStores < ActiveRecord::Migration[8.0]
  def change
    add_column :moysklad_stores, :total_products_count, :integer
    add_column :moysklad_stores, :nonzero_products_count, :integer
    add_column :moysklad_stores, :stock_stats_synced_at, :datetime
  end
end
