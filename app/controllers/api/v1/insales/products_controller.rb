# frozen_string_literal: true

module Api
  module V1
    module Insales
      class ProductsController < BaseController
        before_action :ensure_read_enabled!

        def show
          product = find_product
          raise ActiveRecord::RecordNotFound if product.nil?

          render json: ::Insales::ApiV1::ProductDtoSerializer.new(product).as_json
        end

        def changes
          limit = params.fetch(:limit, 100).to_i.clamp(1, 500)
          include_deleted = ActiveModel::Type::Boolean.new.cast(params[:include_deleted])

          payload = ::Insales::ApiV1::ChangesFeed.new.call(
            cursor: params[:cursor],
            limit: limit,
            include_deleted: include_deleted
          )

          render json: payload
        rescue ArgumentError => e
          render_error(code: 'VALIDATION_ERROR', message: e.message, status: :unprocessable_entity)
        end

        def destroy
          ensure_write_enabled!
          product = find_product
          raise ActiveRecord::RecordNotFound if product.nil?

          payload = ::Insales::ApiV1::ProductDtoSerializer.new(product).as_json
          ::Insales::ApiV1::OutboxPublisher.publish!(
            aggregate_type: 'Product',
            aggregate_id: product.id,
            event_type: 'product.deleted',
            payload: payload.merge('deleted_at' => Time.current.iso8601),
            occurred_at: Time.current
          )

          render json: { status: 'deleted' }
        end

        private

        def find_product
          key = params[:external_id].to_s
          case params[:by].to_s
          when 'sku'
            Product.find_by(sku: key)
          else
            Product.find_by(id: key) || Product.find_by(ms_id: key) || Product.find_by(sku: key)
          end
        end
      end
    end
  end
end
