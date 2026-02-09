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
        provided = params[:token].presence ||
                   request.get_header('HTTP_X_MOYSKLAD_TOKEN').presence ||
                   request.get_header('X-Moysklad-Token').presence
        expected = ENV['MOYSKLAD_WEBHOOK_TOKEN'].to_s

        if expected.blank?
          Rails.logger.warn('[Moysklad Webhook] Missing MOYSKLAD_WEBHOOK_TOKEN in env')
          return head :unauthorized
        end

        if provided.present? && ActiveSupport::SecurityUtils.secure_compare(provided.to_s, expected)
          return
        end

        Rails.logger.warn(
          "[Moysklad Webhook] Unauthorized access, token mismatch " \
          "expected_present=#{expected.present?} token_present=#{provided.present?} " \
          "token_prefix=#{mask_token(provided)} expected_prefix=#{mask_token(expected)}"
        )
        head :unauthorized
      end

      def mask_token(token)
        token = token.to_s
        return 'none' if token.empty?

        token.length <= 4 ? "#{token}****" : "#{token[0, 4]}****"
      end
    end
  end
end
