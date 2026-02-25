# frozen_string_literal: true

module Insales
  class SyncCategoryMappingsJob < ApplicationJob
    queue_as :default

    def perform
      run = InsalesCategorySyncRun.create!(started_at: Time.current, status: 'running')
      result = Insales::CategoryMappingSync.new.call
      run.update!(
        processed: result.processed,
        created: result.created,
        updated: result.updated,
        error_count: result.errors,
        finished_at: Time.current,
        status: result.errors.to_i.positive? ? 'failed' : 'success'
      )
    rescue StandardError => e
      run&.update!(
        status: 'failed',
        finished_at: Time.current,
        last_error: "#{e.class}: #{e.message}"
      )
      raise
    end
  end
end
