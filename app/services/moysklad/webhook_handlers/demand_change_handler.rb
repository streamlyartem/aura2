# frozen_string_literal: true

module Moysklad
  module WebhookHandlers
    class DemandChangeHandler < BaseHandler
      def handle
        changed_product_ids = MoyskladSync.new.import_stocks
        Rails.logger.info(
          "[Moysklad Webhook] Demand event processed, changed_stock_products=#{Array(changed_product_ids).size}"
        )
      end
    end
  end
end
