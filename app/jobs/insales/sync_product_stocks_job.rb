# frozen_string_literal: true

module Insales
  class SyncProductStocksJob < ApplicationJob
    queue_as :default

    def perform(store_name: 'Тест')
      run = InsalesSyncRun.create!(store_name: store_name, started_at: Time.current)
      result = Insales::SyncProductStocks.new.call(store_name: store_name)
      run.update!(
        total_products: result.processed,
        processed: result.processed,
        created: result.created,
        updated: result.updated,
        errors: result.errors,
        variants_updated: result.variant_updates,
        finished_at: Time.current
      )
    end
  end
end
