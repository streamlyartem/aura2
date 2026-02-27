# frozen_string_literal: true

require "securerandom"

module Insales
  module StockChangeEvents
    class Processor
      DEFAULT_BATCH_SIZE = ENV.fetch("INSALES_STOCK_EVENTS_BATCH_SIZE", 200).to_i
      DEFAULT_MAX_BATCHES = ENV.fetch("INSALES_STOCK_EVENTS_MAX_BATCHES", 30).to_i
      STALE_LOCK_TTL = ENV.fetch("INSALES_STOCK_EVENTS_LOCK_TTL_SECONDS", 300).to_i.seconds

      def initialize(worker_id: SecureRandom.hex(8), sync_service: Insales::SyncProductTrigger.new)
        @worker_id = worker_id
        @sync_service = sync_service
      end

      def process(batch_size: DEFAULT_BATCH_SIZE, max_batches: DEFAULT_MAX_BATCHES)
        batches = 0
        processed = 0

        loop do
          break if batches >= max_batches

          release_stale_processing!
          events = claim_next_batch(batch_size: batch_size)
          break if events.empty?

          batches += 1
          events.each do |event|
            processed += process_event(event)
          end

          Metrics.report_queue_depth!
        end

        processed
      end

      private

      attr_reader :worker_id, :sync_service

      def claim_next_batch(batch_size:)
        now = Time.current
        claimed = []

        StockChangeEvent.transaction do
          %w[high normal].each do |priority|
            remaining = batch_size - claimed.size
            break if remaining <= 0

            chunk = StockChangeEvent.pending
                                    .for_priority(priority)
                                    .retry_ready(now)
                                    .order(:event_updated_at, :created_at)
                                    .limit(remaining)
                                    .lock("FOR UPDATE SKIP LOCKED")
                                    .to_a
            next if chunk.empty?

            ids = chunk.map(&:id)
            StockChangeEvent.where(id: ids).update_all(
              status: "processing",
              locked_at: now,
              locked_by: worker_id,
              updated_at: now
            )
            claimed.concat(chunk.map do |event|
              event.assign_attributes(status: "processing", locked_at: now, locked_by: worker_id)
              event
            end)
          end
        end

        claimed
      end

      def release_stale_processing!
        cutoff = Time.current - STALE_LOCK_TTL
        count = StockChangeEvent.stale_processing(cutoff).update_all(
          status: "pending",
          locked_at: nil,
          locked_by: nil,
          updated_at: Time.current
        )
        Rails.logger.info("[InSales][StockEvents] released_stale=#{count}") if count.positive?
      end

      def process_event(claimed_event)
        event = StockChangeEvent.find_by(id: claimed_event.id)
        return 0 unless event

        if stale_version?(event:, claimed_version: claimed_event.event_updated_at)
          mark_pending!(event)
          Metrics.track_stale_skip!
          return 0
        end

        catalog_result = Insales::Catalog::Prepare.call(
          product_ids: [event.product_id],
          export_updated_at: event.event_updated_at
        )
        Rails.logger.info(
          "[InSales][StockEvents] prepared product=#{event.product_id} processed=#{catalog_result.processed} " \
          "ready=#{catalog_result.ready} skipped=#{catalog_result.skipped} errors=#{catalog_result.errors} " \
          "event_updated_at=#{event.event_updated_at.iso8601}"
        )

        latest = StockChangeEvent.find_by(product_id: event.product_id)
        if latest && stale_version?(event: latest, claimed_version: claimed_event.event_updated_at)
          mark_pending!(latest)
          Metrics.track_stale_skip!
          return 0
        end

        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = sync_service.call(product_id: event.product_id, reason: "stock_changed")
        sync_seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
        latency_seconds = Time.current - event.created_at

        if result.status == "success"
          deleted = StockChangeEvent.where(id: event.id, event_updated_at: claimed_event.event_updated_at).delete_all
          if deleted.zero?
            Metrics.track_stale_skip!
            Rails.logger.info(
              "[InSales][StockEvents] newer_event_preserved product=#{event.product_id} claimed_at=#{claimed_event.event_updated_at.iso8601}"
            )
            return 0
          end

          Metrics.track_sync_latency!(latency_seconds)
          Rails.logger.info(
            "[InSales][StockEvents] synced product=#{event.product_id} result=success " \
            "attempts=#{event.attempts} event_updated_at=#{event.event_updated_at.iso8601} " \
            "sync_seconds=#{sync_seconds.round(3)}"
          )
          return 1
        end

        retryable = retryable_error?(result.message)
        handle_failure(event:, message: result.message, retryable:)
        0
      rescue StandardError => e
        handle_failure(event: event, message: "#{e.class}: #{e.message}", retryable: true) if event
        0
      end

      def stale_version?(event:, claimed_version:)
        event.event_updated_at && claimed_version && event.event_updated_at > claimed_version
      end

      def mark_pending!(event)
        event.update!(
          status: "pending",
          locked_at: nil,
          locked_by: nil,
          next_retry_at: nil
        )
      end

      def handle_failure(event:, message:, retryable:)
        if retryable
          attempts = event.attempts.to_i + 1
          event.update!(
            status: "pending",
            attempts: attempts,
            next_retry_at: Time.current + backoff_for(attempts),
            locked_at: nil,
            locked_by: nil,
            last_error: message
          )
          Metrics.track_retry!
          Rails.logger.warn(
            "[InSales][StockEvents] sync_retry product=#{event.product_id} attempts=#{attempts} " \
            "next_retry_at=#{event.next_retry_at&.iso8601} error=#{message}"
          )
        else
          event.update!(
            status: "failed",
            locked_at: nil,
            locked_by: nil,
            last_error: message
          )
          Rails.logger.error(
            "[InSales][StockEvents] sync_failed product=#{event.product_id} attempts=#{event.attempts} error=#{message}"
          )
        end
      end

      def retryable_error?(message)
        text = message.to_s
        return true if text.match?(/Timeout|ConnectionFailed|Net::ReadTimeout/i)

        if (match = text.match(/HTTP\s+(\d{3})/))
          code = match[1].to_i
          return true if code == 429 || code >= 500

          return false
        end

        false
      end

      def backoff_for(attempt)
        case attempt
        when 1 then 1.minute
        when 2 then 5.minutes
        when 3 then 15.minutes
        else 1.hour
        end
      end
    end
  end
end
