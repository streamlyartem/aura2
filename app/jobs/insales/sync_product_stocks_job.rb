# frozen_string_literal: true

module Insales
  class SyncProductStocksJob < ApplicationJob
    queue_as :default

    def perform(store_name: 'Тест')
      Rails.logger.info("[InSalesSync] Job started store=#{store_name}")
      run = InsalesSyncRun.create!(store_name: store_name, started_at: Time.current, status: 'running')
      upsert_status(store_name, nil, running: true)
      result = Insales::SyncProductStocks.new.call(store_name: store_name)
      run.update!(
        total_products: result.processed,
        processed: result.processed,
        created: result.created,
        updated: result.updated,
        error_count: result.errors,
        variants_updated: result.variant_updates,
        images_uploaded: result.images_uploaded,
        images_skipped: result.images_skipped,
        images_errors: result.images_errors,
        videos_uploaded: result.videos_uploaded,
        videos_skipped: result.videos_skipped,
        verify_failures: result.verify_failures,
        last_http_status: result.last_http_status,
        last_http_endpoint: result.last_http_endpoint,
        last_verified_at: Time.current,
        last_error: result.last_error_message,
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

    def upsert_status(store_name, result, error: nil, running: false)
      status = InsalesStockSyncState.find_or_initialize_by(store_name: store_name)
      status.last_run_at = Time.current

      if running
        status.last_status = 'running'
      elsif result
        status.last_stock_sync_at = Time.current
        status.last_status = result.errors.to_i.positive? ? 'failed' : 'success'
        status.processed = result.processed
        status.created = result.created
        status.updated = result.updated
        status.error_count = result.errors
        status.variants_updated = result.variant_updates
        status.images_uploaded = result.images_uploaded
        status.images_skipped = result.images_skipped
        status.images_errors = result.images_errors
        status.videos_uploaded = result.videos_uploaded
        status.videos_skipped = result.videos_skipped
        status.verify_failures = result.verify_failures
        status.last_http_status = result.last_http_status
        status.last_http_endpoint = result.last_http_endpoint
        status.last_verified_at = Time.current
        status.last_error = result.last_error_message
      elsif error
        status.last_status = 'failed'
        status.last_error = "#{error.class}: #{error.message}"
      end

      status.save!
    end
  end
end
