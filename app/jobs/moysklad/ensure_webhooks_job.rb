# frozen_string_literal: true

module Moysklad
  class EnsureWebhooksJob < ApplicationJob
    queue_as :default

    def perform
      run = MoyskladSyncRun.create!(run_type: 'webhooks', started_at: Time.current, status: 'running')
      result = Moysklad::WebhooksManager.new.ensure
      run.update!(
        processed: result.created + result.skipped,
        created: result.created,
        updated: 0,
        error_count: result.errors,
        finished_at: Time.current,
        status: result.errors.positive? ? 'failed' : 'success'
      )
      Rails.logger.info("[MoySklad] Result created=#{result.created} skipped=#{result.skipped} errors=#{result.errors}")
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
