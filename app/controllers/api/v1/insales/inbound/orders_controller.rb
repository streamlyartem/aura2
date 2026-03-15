# frozen_string_literal: true

require 'openssl'

module Api
  module V1
    module Insales
      module Inbound
        class OrdersController < BaseController
          skip_before_action :authenticate_api!
          before_action :ensure_inbound_enabled!
          before_action :authenticate_inbound_request!

          def create
            ingested = ::Insales::ApiV1::InboundOrders::Ingestor.new.call(payload: request_payload, source: 'insales')

            enqueue_processing(ingested.event.id) if should_enqueue_processing?

            render json: {
              status: ingested.replay ? 'replayed' : 'accepted',
              replay: ingested.replay,
              event_id: ingested.event.id,
              external_order_id: ingested.order&.external_order_id
            }, status: :accepted
          end

          private

          def ensure_inbound_enabled!
            return if ::Insales::ApiV1::FeatureFlags.inbound_orders_enabled?

            render_error(code: 'FORBIDDEN', message: 'Inbound orders endpoint is disabled', status: :forbidden)
          end

          def authenticate_inbound_request!
            secret = ::Insales::ApiV1::FeatureFlags.inbound_orders_secret
            if secret.present?
              verify_hmac!(secret)
            else
              authenticate_api!
            end
          rescue ::Insales::ApiV1::ErrorResponse => e
            render_api_error(e)
          end

          def verify_hmac!(secret)
            timestamp = request.headers['X-Insales-Timestamp'].to_s
            signature = request.headers['X-Insales-Signature'].to_s
            raise ::Insales::ApiV1::ErrorResponse.new(code: 'UNAUTHORIZED', message: 'Missing signature headers', status: :unauthorized) if timestamp.blank? || signature.blank?

            ts = Integer(timestamp)
            now = Time.current.to_i
            if (now - ts).abs > 300
              raise ::Insales::ApiV1::ErrorResponse.new(code: 'REPLAY_REJECTED', message: 'Timestamp outside replay window', status: :unauthorized)
            end

            payload = "#{timestamp}.#{request.raw_post}"
            expected = OpenSSL::HMAC.hexdigest('SHA256', secret, payload)
            secure = ActiveSupport::SecurityUtils.secure_compare(expected, signature)
            raise ::Insales::ApiV1::ErrorResponse.new(code: 'UNAUTHORIZED', message: 'Invalid signature', status: :unauthorized) unless secure
          rescue ArgumentError
            raise ::Insales::ApiV1::ErrorResponse.new(code: 'UNAUTHORIZED', message: 'Invalid timestamp header', status: :unauthorized)
          end

          def request_payload
            raw = request.raw_post.to_s
            return {} if raw.blank?

            JSON.parse(raw)
          rescue JSON::ParserError
            raise ::Insales::ApiV1::ErrorResponse.new(code: 'VALIDATION_ERROR', message: 'Invalid JSON payload', status: :unprocessable_entity)
          end

          def should_enqueue_processing?
            ::Insales::ApiV1::FeatureFlags.inbound_orders_processing_enabled?
          end

          def enqueue_processing(event_id)
            ::Insales::ApiV1::InboundOrderEventJob.perform_later(event_id: event_id)
          end
        end
      end
    end
  end
end
