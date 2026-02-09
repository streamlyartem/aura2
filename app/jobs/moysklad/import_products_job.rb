# frozen_string_literal: true

module Moysklad
  class ImportProductsJob < ApplicationJob
    queue_as :default

    def perform
      Rails.logger.info('[Moysklad] Import products job started')
      MoyskladSync.new.import_products
      Rails.logger.info('[Moysklad] Import products job finished')
    end
  end
end
