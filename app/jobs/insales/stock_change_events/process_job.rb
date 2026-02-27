# frozen_string_literal: true

module Insales
  module StockChangeEvents
    class ProcessJob < ApplicationJob
      queue_as :default

      retry_on ActiveRecord::Deadlocked, wait: :exponentially_longer, attempts: 5

      def perform(batch_size: nil, max_batches: nil)
        processed = Processor.new.process(
          batch_size: batch_size || Processor::DEFAULT_BATCH_SIZE,
          max_batches: max_batches || Processor::DEFAULT_MAX_BATCHES
        )
        Rails.logger.info("[InSales][StockEvents] ProcessJob finished processed=#{processed}")
      end
    end
  end
end
