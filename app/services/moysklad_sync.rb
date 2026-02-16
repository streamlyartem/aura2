# frozen_string_literal: true

class MoyskladSync
  include MoyskladHelper

  def initialize(client = MoyskladClient.new())
    @client = client
  end

  def import_products
    count = 0

    @client.each_product do |ms_product_payload|
      ms_product = Moysklad::Product.new(ms_product_payload)

      product = Product.find_or_initialize_by(sku: ms_product.sku)

      product.assign_attributes(
        ms_id: ms_product.id,
        name: ms_product.name,
        batch_number: ms_product.batch_number,
        path_name: ms_product.path_name,
        weight: ms_product.weight&.to_f,
        length: ms_product.length&.to_f,
        color: ms_product.color,
        tone: ms_product.tone,
        ombre: ms_product.ombre,
        code: ms_product.code,
        barcodes: ms_product.barcodes,
        purchase_price: ms_product.purchase_price&.to_f,
        retail_price: ms_product.retail_price&.to_f,
        small_wholesale_price: ms_product.small_wholesale_price&.to_f,
        large_wholesale_price: ms_product.large_wholesale_price&.to_f,
        five_hundred_plus_wholesale_price: ms_product.five_hundred_plus_wholesale_price&.to_f,
        min_price: ms_product.min_price&.to_f
      )

      product.save!

      count += 1
      Rails.logger.info "[MoyskladSync] Imported ##{count} #{product.sku}" if (count % 100).zero?
    end

    Rails.logger.info "[MoyskladSync] Import finished, total: #{count}"
    count
  end

  def import_stocks
    changed_product_ids = []

    @client.stocks_for_store.each do |row|
      ms_product_uuid = extract_uuid(row[:product_meta]['href'])

      Rails.logger.info "[MoyskladSync] name: #{row[:name]} - #{ms_product_uuid}"

      product = Product.find_by(ms_id: ms_product_uuid)
      next unless product

      product_stock = ProductStock.find_or_initialize_by(product_id: product.id, store_name: row[:store_name])
      new_stock = row[:stock].to_f
      new_free_stock = row[:free_stock].to_f
      new_reserve = row[:reserve].to_f
      next unless stock_changed?(product_stock, new_stock, new_free_stock, new_reserve)

      product_stock.assign_attributes(
        stock: new_stock,
        free_stock: new_free_stock,
        reserve: new_reserve,
        synced_at: Time.current
      )
      product_stock.save!
      changed_product_ids << product.id
    end

    changed_product_ids.uniq
  end

  private

  def stock_changed?(product_stock, stock, free_stock, reserve)
    product_stock.stock.to_f != stock ||
      product_stock.free_stock.to_f != free_stock ||
      product_stock.reserve.to_f != reserve
  end
end
