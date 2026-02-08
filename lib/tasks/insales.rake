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

    Insales::ExportProducts.call(product_id: product_id, dry_run: dry_run)
    Insales::ExportImages.call(product_id: product_id, dry_run: dry_run, limit: 2)

    mapping = InsalesProductMapping.find_by(aura_product_id: product_id)
    puts "insales_product_id=#{mapping&.insales_product_id}"
  end
end

def env_truthy?(value)
  return false if value.nil?

  %w[1 true yes y].include?(value.to_s.downcase)
end
