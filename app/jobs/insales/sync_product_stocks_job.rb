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
        error_count: result.errors,
        variants_updated: result.variant_updates,
        finished_at: Time.current,
        status: result.errors.positive? ? 'error' : 'success'
      )
      Rails.logger.info("[InSalesSync] Job finished store=#{store_name} status=#{run.status}")
    rescue StandardError => e
      Rails.logger.error("[InSalesSync] Job failed store=#{store_name}: #{e.class} - #{e.message}")
      run&.update!(
        status: 'error',
        finished_at: Time.current,
        error_details: format_error(e)
      )
      raise
    end

    def format_error(error)
      {
        class: error.class.name,
        message: error.message,
        backtrace: Array(error.backtrace).first(20)
      }.to_json
    end
  end
end
