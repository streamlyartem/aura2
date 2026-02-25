# frozen_string_literal: true

module Insales
  class SyncProductStocksJob < ApplicationJob
    queue_as :default

    def perform(store_names: nil)
      store_names = normalize_store_names(store_names)
      store_label = store_names.join(', ')
      Rails.logger.info("[InSalesSync] Job started stores=#{store_label}")
      run = InsalesSyncRun.create!(store_name: store_label, started_at: Time.current, status: 'running')
      upsert_status(store_label, nil, running: true)
      result = Insales::SyncProductStocks.new.call(store_names: store_names)
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
      upsert_status(store_label, result)
      Rails.logger.info("[InSalesSync] Job finished stores=#{store_label} status=#{run.status}")
    rescue StandardError => e
      Rails.logger.error("[InSalesSync] Job failed stores=#{store_names}: #{e.class} - #{e.message}")
      run&.update!(
        status: 'error',
        finished_at: Time.current,
        error_details: format_error(e)
      )
      upsert_status(store_label || '—', nil, error: e)
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

    def normalize_store_names(store_names)
      names = Array(store_names.presence || InsalesSetting.first&.allowed_store_names)
      names = names.map(&:to_s).map(&:strip).reject(&:blank?).uniq
      names = [MoyskladClient::TEST_STORE_NAME] if names.empty?
      names
    end
  end
end
