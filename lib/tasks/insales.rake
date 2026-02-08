# frozen_string_literal: true

namespace :insales do
  desc 'Sync products to InSales (PRODUCT_ID optional)'
  task products: :environment do
    product_id = ENV['PRODUCT_ID']
    dry_run = env_truthy?(ENV['DRY_RUN'])

    result = Insales::ExportProducts.call(product_id: product_id, dry_run: dry_run)
    puts result.inspect
  end

  desc 'Sync product images to InSales (PRODUCT_ID required)'
  task images: :environment do
    product_id = ENV['PRODUCT_ID']
    dry_run = env_truthy?(ENV['DRY_RUN'])

    result = Insales::ExportImages.call(product_id: product_id, dry_run: dry_run)
    puts result.inspect
  end

  desc 'Smoke test: export one product and 1-2 images'
  task smoke: :environment do
    product_id = ENV['PRODUCT_ID']
    raise ArgumentError, 'PRODUCT_ID is required' if product_id.blank?

    dry_run = env_truthy?(ENV['DRY_RUN'])

    products_result = Insales::ExportProducts.call(product_id: product_id, dry_run: dry_run)
    images_result = Insales::ExportImages.call(product_id: product_id, dry_run: dry_run)

    mapping = InsalesProductMapping.find_by(aura_product_id: product_id)
    puts "insales_product_id=#{mapping&.insales_product_id}"
    puts "products=#{products_result.inspect} images=#{images_result.inspect}"
  end
end

def env_truthy?(value)
  return false if value.nil?

  %w[1 true yes y].include?(value.to_s.downcase)
end

namespace :insales do
  desc 'Sync store stock to InSales'
  task sync_store: :environment do
    store_name = ENV.fetch('STORE_NAME', 'Тест')
    collection_id = ENV['COLLECTION_ID']
    update_product_fields = env_truthy?(ENV['UPDATE_PRODUCT_FIELDS'])
    sync_images = env_truthy?(ENV['SYNC_IMAGES'])

    result = Insales::SyncProductStocks.new.call(store_name: store_name)

    puts result.inspect
  end
end
