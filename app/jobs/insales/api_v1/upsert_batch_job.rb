# frozen_string_literal: true

module Insales
  module ApiV1
    class UpsertBatchJob < ApplicationJob
      queue_as :default

      def perform(run_id:, items:)
        run = InsalesApiSyncRun.find(run_id)
        Insales::ApiV1::UpsertBatchRunner.new.call(run: run, items: items)
      end
    end
  end
end
