# frozen_string_literal: true

module Insales
  class SyncProductStocksJob < ApplicationJob
    queue_as :default

    def perform(store_name: 'Тест')
      Insales::SyncProductStocks.new.call(store_name: store_name)
    end
  end
end
