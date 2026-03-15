# frozen_string_literal: true

module Insales
  module ApiV1
    class FullSyncJob < ApplicationJob
      queue_as :default

      def perform(run_id:, limit: nil)
        run = InsalesApiSyncRun.find(run_id)
        run.update!(status: 'running', started_at: Time.current)

        processed = 0
        Product.order(updated_at: :desc).limit(limit.presence || 3000).find_each do |product|
          payload = Insales::ApiV1::ProductDtoSerializer.new(product).as_json
          Insales::ApiV1::OutboxPublisher.publish!(
            aggregate_type: 'Product',
            aggregate_id: product.id,
            event_type: 'product.updated',
            payload: payload,
            occurred_at: product.updated_at || Time.current
          )
          processed += 1
          run.increment!(:processed)
        end

        run.update!(
          status: 'success',
          finished_at: Time.current,
          total_items: processed,
          unchanged_count: processed
        )
      rescue StandardError => e
        run&.update!(status: 'failed', finished_at: Time.current, last_error: "#{e.class}: #{e.message}")
        raise
      end
    end
  end
end
