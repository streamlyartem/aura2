# frozen_string_literal: true

module Insales
  module ApiV1
    class InboundOrderEventJob < ApplicationJob
      queue_as :default

      def perform(event_id:)
        Insales::ApiV1::InboundOrders::Processor.new.process(event_id: event_id)
      end
    end
  end
end
