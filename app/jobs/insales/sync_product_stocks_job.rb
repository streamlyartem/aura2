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
      upsert_status(store_name, result)
      Rails.logger.info("[InSalesSync] Job finished store=#{store_name} status=#{run.status}")
    rescue StandardError => e
      Rails.logger.error("[InSalesSync] Job failed store=#{store_name}: #{e.class} - #{e.message}")
      run&.update!(
        status: 'error',
        finished_at: Time.current,
        error_details: format_error(e)
      )
      upsert_status(store_name, nil, error: e)
      raise
    end

    def format_error(error)
      {
        class: error.class.name,
        message: error.message,
        backtrace: Array(error.backtrace).first(20)
      }.to_json
    end

    def upsert_status(store_name, result, error: nil)
      status = InsalesStockSyncState.find_or_initialize_by(store_name: store_name)
      status.last_run_at = Time.current

      if result
        status.last_stock_sync_at = Time.current
        status.last_status = 'success'
        status.processed = result.processed
        status.created = result.created
        status.updated = result.updated
        status.errors = result.errors
        status.variants_updated = result.variant_updates
        status.last_error = nil
      elsif error
        status.last_status = 'failed'
        status.last_error = "#{error.class}: #{error.message}"
      end

      status.save!
    end
  end
end
