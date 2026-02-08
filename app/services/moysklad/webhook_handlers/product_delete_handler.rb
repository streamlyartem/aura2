# frozen_string_literal: true

module Moysklad
  module WebhookHandlers
    class ProductDeleteHandler < BaseHandler
      def handle
        id = extract_id_from_href
        return unless id

        product = ::Product.find_by(ms_id: id)
        if product
          product.destroy!
          Rails.logger.info "[Moysklad Webhook] Product #{product.id} deleted (from Moysklad)"
        else
          Rails.logger.warn "[Moysklad Webhook] Tried to delete non-existent product #{id}"
        end
      end
    end
  end
end
