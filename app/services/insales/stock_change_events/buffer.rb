# frozen_string_literal: true

module Insales
  module StockChangeEvents
    class Buffer
      def initialize(priority_resolver: PriorityResolver.new)
        @priority_resolver = priority_resolver
      end

      def self.call(...)
        new.call(...)
      end

      def call(product_id:, store_name:, new_stock:, event_updated_at:, price_impact: false)
        return if product_id.blank?

        resolved = priority_resolver.call(
          store_name: store_name,
          new_stock: new_stock,
          price_impact: price_impact
        )

        upsert_event(
          product_id: product_id,
          priority: resolved.priority,
          reason: resolved.reason,
          event_updated_at: event_updated_at || Time.current
        )
      end

      private

      attr_reader :priority_resolver

      def upsert_event(product_id:, priority:, reason:, event_updated_at:)
        now = Time.current
        connection = ActiveRecord::Base.connection
        product_id_sql = connection.quote(product_id)
        priority_sql = connection.quote(priority)
        reason_sql = connection.quote(reason)
        event_updated_at_sql = connection.quote(event_updated_at)
        now_sql = connection.quote(now)

        sql = <<~SQL.squish
          INSERT INTO stock_change_events
            (id, product_id, priority, reason, event_updated_at, status, attempts, next_retry_at, created_at, updated_at)
          VALUES
            (gen_random_uuid(), #{product_id_sql}, #{priority_sql}, #{reason_sql}, #{event_updated_at_sql}, 'pending', 0, NULL, #{now_sql}, #{now_sql})
          ON CONFLICT (product_id) DO UPDATE SET
            event_updated_at = GREATEST(stock_change_events.event_updated_at, EXCLUDED.event_updated_at),
            priority = CASE
              WHEN stock_change_events.priority = 'high' OR EXCLUDED.priority = 'high' THEN 'high'
              ELSE 'normal'
            END,
            reason = CASE
              WHEN stock_change_events.priority = 'high' THEN stock_change_events.reason
              WHEN EXCLUDED.priority = 'high' THEN EXCLUDED.reason
              ELSE EXCLUDED.reason
            END,
            status = 'pending',
            attempts = 0,
            next_retry_at = NULL,
            locked_at = NULL,
            locked_by = NULL,
            updated_at = EXCLUDED.updated_at
        SQL

        connection.execute(sql)
      end
    end
  end
end
