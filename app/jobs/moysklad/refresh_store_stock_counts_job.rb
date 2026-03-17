# frozen_string_literal: true

module Moysklad
  class RefreshStoreStockCountsJob < ApplicationJob
    queue_as :default

    def perform(store_id)
      store = MoyskladStore.find_by(id: store_id)
      return unless store

      store.refresh_stock_counts!
    end
  end
end
