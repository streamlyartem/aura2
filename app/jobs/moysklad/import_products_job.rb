# frozen_string_literal: true

require 'zlib'

module Moysklad
  class ImportProductsJob < ApplicationJob
    queue_as :default
    retry_on Faraday::TimeoutError, Faraday::ConnectionFailed, Net::ReadTimeout, wait: 30.seconds, attempts: 3

    LOCK_NAMESPACE = 53_017
    LOCK_NAME = 'moysklad_import_products'

    class << self
      def enqueue_once
        enqueued = false

        locked = with_singleton_lock do
          next if queued_or_running? || running_import_exists?

          perform_later
          enqueued = true
        end

        locked && enqueued
      end

      def queued_or_running?
        job_ids = SolidQueue::Job.where(class_name: name).select(:id)

        SolidQueue::ReadyExecution.where(job_id: job_ids).exists? ||
          SolidQueue::ScheduledExecution.where(job_id: job_ids).exists? ||
          SolidQueue::ClaimedExecution.where(job_id: job_ids).exists? ||
          SolidQueue::BlockedExecution.where(job_id: job_ids).exists?
      end

      def running_import_exists?
        MoyskladSyncRun.imports.running.exists?
      end

      def with_singleton_lock
        key = advisory_lock_key

        ActiveRecord::Base.connection_pool.with_connection do |connection|
          obtained = connection.select_value("SELECT pg_try_advisory_lock(#{key}::bigint)")
          return false unless obtained

          yield
          true
        ensure
          connection.execute("SELECT pg_advisory_unlock(#{key}::bigint)") if obtained
        end
      end

      private

      def advisory_lock_key
        crc = Zlib.crc32(LOCK_NAME)
        value = ((LOCK_NAMESPACE & 0xffffffff) << 32) | (crc & 0xffffffff)
        value > 0x7fffffffffffffff ? value - 0x10000000000000000 : value
      end
    end

    def perform
      locked = self.class.with_singleton_lock do
        run = MoyskladSyncRun.create!(run_type: 'import_products', started_at: Time.current, status: 'running')
        Rails.logger.info('[Moysklad] Import products job started')

        result = MoyskladSync.new.import_products(stop_requested: stop_requested_checker(run.id))

        run.update!(
          processed: result[:processed],
          created: nil,
          updated: nil,
          error_count: 0,
          finished_at: Time.current,
          status: result[:stopped] ? 'stopped' : 'success',
          last_error: result[:stopped] ? 'Stopped by user' : nil
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

      return if locked

      MoyskladSyncRun.create!(
        run_type: 'import_products',
        started_at: Time.current,
        finished_at: Time.current,
        status: 'skipped',
        processed: 0,
        created: nil,
        updated: nil,
        error_count: 0,
        last_error: 'Skipped: import already running'
      )
      Rails.logger.info('[Moysklad] Import products job skipped: lock_not_acquired')
    end

    private

    def stop_requested_checker(run_id)
      lambda do
        MoyskladSyncRun.where(id: run_id).where.not(stop_requested_at: nil).exists?
      end
    end
  end
end
