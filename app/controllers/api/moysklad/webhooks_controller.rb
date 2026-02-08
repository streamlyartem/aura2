# frozen_string_literal: true

module Api
  module Moysklad
    class WebhooksController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :verify_moysklad_token!

      def create
        Rails.logger.info "[Moysklad Webhook] Received: #{params.to_unsafe_h}"

        events = params[:events] || []
        events.each do |event|
          ::Moysklad::WebhookRouter.new(event).handle
        end

        head :ok
      rescue StandardError => e
        Rails.logger.error "[Moysklad Webhook] Error: #{e.class} - #{e.message}"
        head :internal_server_error
      end

      private

      def verify_moysklad_token!
        provided = params[:token].to_s
        expected = ENV['MOYSKLAD_WEBHOOK_TOKEN'].to_s

        return if ActiveSupport::SecurityUtils.secure_compare(provided, expected)

        Rails.logger.warn '[Moysklad Webhook] Unauthorized access, token mismatch'
        head :unauthorized
      end
    end
  end
end
