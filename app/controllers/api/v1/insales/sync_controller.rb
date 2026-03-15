# frozen_string_literal: true

module Api
  module V1
    module Insales
      class SyncController < BaseController
        before_action :ensure_read_enabled!, only: :show_run
        before_action :ensure_write_enabled!, except: :show_run

        def upsert
          idempotency_key = request.headers['Idempotency-Key'].to_s
          if idempotency_key.blank?
            return render_error(code: 'VALIDATION_ERROR', message: 'Idempotency-Key header is required', status: :unprocessable_entity)
          end

          store = ::Insales::ApiV1::IdempotencyStore.new
          idempotency = store.fetch_or_reserve!(key: idempotency_key, raw_body: request.raw_post)

          if idempotency.replay
            return render json: idempotency.record.response_body, status: idempotency.record.response_status
          end

          payload = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
          payload = payload.except('controller', 'action')

          items = Array(payload['items'] || payload[:items])
          batch_id = payload['batch_id'] || payload[:batch_id] || SecureRandom.uuid
          source = payload['source'] || payload[:source] || 'unknown'

          run = InsalesApiSyncRun.create!(
            run_type: 'upsert',
            status: 'queued',
            source: source,
            batch_id: batch_id,
            idempotency_key: idempotency_key,
            total_items: items.size
          )

          ::Insales::ApiV1::UpsertBatchJob.perform_later(run_id: run.id, items: items)

          body = { run_id: run.id, status: 'queued', batch_id: batch_id }
          store.persist_response!(record: idempotency.record, status: 202, body: body)

          render json: body, status: :accepted
        end

        def full
          limit = params[:limit].presence&.to_i
          run = InsalesApiSyncRun.create!(
            run_type: 'full_sync',
            status: 'queued',
            source: 'aura',
            total_items: limit || 3000,
            meta: { dry_run: ActiveModel::Type::Boolean.new.cast(params[:dry_run]), limit: limit }
          )

          ::Insales::ApiV1::FullSyncJob.perform_later(run_id: run.id, limit: limit)

          render json: { run_id: run.id, status: 'queued' }, status: :accepted
        end

        def show_run
          run = InsalesApiSyncRun.find(params[:run_id])
          render json: {
            run_id: run.id,
            status: run.status,
            started_at: run.started_at,
            finished_at: run.finished_at,
            stats: {
              processed: run.processed,
              created: run.created_count,
              updated: run.updated_count,
              unchanged: run.unchanged_count,
              skipped: run.skipped_count,
              failed: run.failed_count
            },
            errors: run.error_items
          }
        end
      end
    end
  end
end
