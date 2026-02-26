# frozen_string_literal: true

module Moysklad
  class ImportProductsJob < ApplicationJob
    queue_as :default
    retry_on Faraday::TimeoutError, Faraday::ConnectionFailed, Net::ReadTimeout, wait: 30.seconds, attempts: 3

    def perform
      run = MoyskladSyncRun.create!(run_type: 'import_products', started_at: Time.current, status: 'running')
      Rails.logger.info('[Moysklad] Import products job started')
      count = MoyskladSync.new.import_products
      run.update!(
        processed: count,
        created: nil,
        updated: nil,
        error_count: 0,
        finished_at: Time.current,
        status: 'success'
      )
      Rails.logger.info('[Moysklad] Import products job finished')
    rescue StandardError => e
      run&.update!(
        status: 'failed',
        finished_at: Time.current,
        last_error: "#{e.class}: #{e.message}"
      )
      raise
    end
  end
end
