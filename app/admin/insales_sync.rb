# frozen_string_literal: true

ActiveAdmin.register_page 'Insales Sync' do
  menu priority: 5, label: 'InSales Sync'

  content title: 'InSales Sync' do
    store_name = defined?(MoyskladClient::TEST_STORE_NAME) ? MoyskladClient::TEST_STORE_NAME : 'Тест'

    stock_scope = ProductStock.where(store_name: store_name)
    last_stock_sync_at = stock_scope.maximum(:synced_at)

    products_with_stock = stock_scope.select(:product_id).distinct.count
    total_stocks = stock_scope.count

    products_with_insales_mapping = InsalesProductMapping.count
    images_with_insales_mapping = InsalesImageMapping.count

    panel "Test store sync status (#{store_name})" do
      table_for [
        ['Last stock sync', last_stock_sync_at || '—'],
        ['Products with stock records', products_with_stock],
        ['Stock rows', total_stocks],
        ['Products mapped to InSales', products_with_insales_mapping],
        ['Images mapped to InSales', images_with_insales_mapping]
      ] do
        column('Metric') { |row| row[0] }
        column('Value') { |row| row[1] }
      end
    end
  end
end
