# frozen_string_literal: true

module Insales
  module ApiV1
    class OutboxPublisher
      def publish!(aggregate_type:, aggregate_id:, event_type:, payload:, occurred_at: Time.current)
        return unless FeatureFlags.outbox_enabled?

        SyncOutboxEvent.create!(
          aggregate_type: aggregate_type,
          aggregate_id: aggregate_id.to_s,
          event_type: event_type,
          payload: payload,
          occurred_at: occurred_at
        )
      end

      def self.publish!(...)
        new.publish!(...)
      end
    end
  end
end
