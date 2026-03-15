# frozen_string_literal: true

module Insales
  module ApiV1
    class ChangesFeed
      DELETED_EVENTS = %w[product.deleted].freeze

      def call(cursor:, limit:, include_deleted: false)
        sequence = Cursor.decode(cursor)
        scope = SyncOutboxEvent.after_cursor(sequence).ordered.limit(limit)
        scope = scope.where.not(event_type: DELETED_EVENTS) unless include_deleted

        events = scope.to_a
        items = events.map { |event| serialize_event(event) }

        {
          items: items,
          next_cursor: events.last ? Cursor.encode(events.last.id) : cursor,
          has_more: events.size >= limit,
          cursor_acked_upto: events.last&.id || sequence
        }
      end

      private

      def serialize_event(event)
        {
          event_id: event.event_id,
          sequence_id: event.id,
          event_type: event.event_type,
          occurred_at: event.occurred_at&.iso8601,
          product: event.payload
        }
      end
    end
  end
end
