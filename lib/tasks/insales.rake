# frozen_string_literal: true

namespace :insales do
  desc 'Sync products to InSales'
  task products: :environment do
    params = InsalesTaskParams.from_env
    result = Insales::ExportProducts.call(
      limit: params.limit,
      since: params.since,
      product_id: params.product_id,
      dry_run: params.dry_run
    )
    puts result.inspect
  end

  desc 'Sync product images to InSales'
  task images: :environment do
    params = InsalesTaskParams.from_env
    result = Insales::ExportImages.call(
      limit: params.limit,
      since: params.since,
      product_id: params.product_id,
      only_missing: params.only_missing,
      dry_run: params.dry_run
    )
    puts result.inspect
  end

  desc 'Smoke test: export one product and 1-2 images'
  task smoke: :environment do
    params = InsalesTaskParams.from_env
    raise ArgumentError, 'PRODUCT_ID is required' if params.product_id.blank?

    Insales::ExportProducts.call(
      product_id: params.product_id,
      limit: 1,
      dry_run: params.dry_run
    )

    Insales::ExportImages.call(
      product_id: params.product_id,
      limit: 2,
      only_missing: false,
      dry_run: params.dry_run
    )

    puts 'Smoke completed'
  end
end

class InsalesTaskParams
  attr_reader :limit, :since, :product_id, :only_missing, :dry_run

  def self.from_env
    new(
      limit: ENV['LIMIT'],
      since: ENV['SINCE'],
      product_id: ENV['PRODUCT_ID'],
      only_missing: ENV['ONLY_MISSING'],
      dry_run: ENV['DRY_RUN']
    )
  end

  def initialize(limit:, since:, product_id:, only_missing:, dry_run:)
    @limit = limit.present? ? limit.to_i : nil
    @since = since.present? ? Time.zone.parse(since) : nil
    @product_id = product_id.presence
    @only_missing = truthy?(only_missing)
    @dry_run = truthy?(dry_run)
  end

  private

  def truthy?(value)
    return false if value.nil?

    %w[1 true yes y].include?(value.to_s.downcase)
  end
end
