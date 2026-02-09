# frozen_string_literal: true

module Insales
  class SyncProductStocksJob < ApplicationJob
    queue_as :default

    def perform(store_name: 'Тест')
      Rails.logger.info("[InSalesSync] Job started store=#{store_name}")
      run = InsalesSyncRun.create!(store_name: store_name, started_at: Time.current, status: 'running')
      result = Insales::SyncProductStocks.new.call(store_name: store_name)
      run.update!(
        total_products: result.processed,
        processed: result.processed,
        created: result.created,
        updated: result.updated,
        errors: result.errors,
        variants_updated: result.variant_updates,
        finished_at: Time.current,
        status: result.errors.positive? ? 'error' : 'success'
      )
      Rails.logger.info("[InSalesSync] Job finished store=#{store_name} status=#{run.status}")
    end
  end
end
