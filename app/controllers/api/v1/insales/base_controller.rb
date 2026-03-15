# frozen_string_literal: true

module Api
  module V1
    module Insales
      class BaseController < ActionController::API
        before_action :authenticate_api!

        rescue_from ::Insales::ApiV1::ErrorResponse, with: :render_api_error
        rescue_from ActiveRecord::RecordNotFound do
          render_error(code: 'PRODUCT_NOT_FOUND', message: 'Product not found', status: :not_found)
        end
        rescue_from ActionController::ParameterMissing do |e|
          render_error(code: 'VALIDATION_ERROR', message: e.message, status: :unprocessable_entity)
        end

        private

        def authenticate_api!
          token = ::Insales::ApiV1::FeatureFlags.auth_token
          return if token.blank?

          provided = bearer_token
          return if provided.present? && ActiveSupport::SecurityUtils.secure_compare(provided, token)

          render_error(code: 'UNAUTHORIZED', message: 'Unauthorized', status: :unauthorized)
        end

        def bearer_token
          header = request.authorization.to_s
          return nil unless header.start_with?('Bearer ')

          header.delete_prefix('Bearer ').strip
        end

        def render_api_error(error)
          render_error(
            code: error.code,
            message: error.message,
            status: error.status,
            details: error.details,
            retryable: error.retryable
          )
        end

        def render_error(code:, message:, status:, details: nil, retryable: false)
          render(
            json: {
              error: {
                code: code,
                message: message,
                details: details,
                trace_id: request.request_id,
                retryable: retryable
              }
            },
            status: status
          )
        end

        def ensure_read_enabled!
          return if ::Insales::ApiV1::FeatureFlags.read_enabled?

          raise ::Insales::ApiV1::ErrorResponse.new(
            code: 'FORBIDDEN',
            message: 'API v1 read endpoints are disabled',
            status: :forbidden
          )
        end

        def ensure_write_enabled!
          return if ::Insales::ApiV1::FeatureFlags.write_enabled?

          raise ::Insales::ApiV1::ErrorResponse.new(
            code: 'FORBIDDEN',
            message: 'API v1 write endpoints are disabled',
            status: :forbidden
          )
        end
      end
    end
  end
end
