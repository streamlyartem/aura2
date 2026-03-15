# frozen_string_literal: true

require 'digest'

module Insales
  module ApiV1
    class IdempotencyStore
      Result = Struct.new(:replay, :record, keyword_init: true)

      TTL = 24.hours

      def fetch_or_reserve!(key:, raw_body:)
        request_hash = Digest::SHA256.hexdigest(raw_body.to_s)
        record = SyncIdempotencyKey.find_by(idempotency_key: key)

        if record
          if record.request_hash != request_hash
            raise ErrorResponse.new(
              code: 'IDEMPOTENCY_CONFLICT',
              message: 'Idempotency key reused with different payload',
              status: :conflict,
              details: { idempotency_key: key }
            )
          end

          replayable = record.response_status.present? && record.response_body.present?
          return Result.new(replay: replayable, record: record)
        end

        record = SyncIdempotencyKey.create!(
          idempotency_key: key,
          request_hash: request_hash,
          expires_at: Time.current + TTL
        )

        Result.new(replay: false, record: record)
      rescue ActiveRecord::RecordNotUnique
        retry
      end

      def persist_response!(record:, status:, body:)
        record.update!(response_status: status.to_i, response_body: body)
      end
    end
  end
end
