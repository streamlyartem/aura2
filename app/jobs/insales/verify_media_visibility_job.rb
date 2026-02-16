# frozen_string_literal: true

module Insales
  class VerifyMediaVisibilityJob < ApplicationJob
    queue_as :default

    retry_on Net::ReadTimeout, Net::OpenTimeout, Timeout::Error, wait: :exponentially_longer, attempts: 3

    def perform(product_id:)
      product = Product.find_by(id: product_id)
      return unless product

      status = InsalesMediaStatus.find_or_initialize_by(product_id: product.id)
      status.update!(status: 'in_progress', last_checked_at: Time.current)

      Insales::VerifyMediaVisibility.new.call(product: product)
    rescue StandardError => e
      status&.update!(status: 'error', last_error: "#{e.class}: #{e.message}", last_checked_at: Time.current)
      raise
    end
  end
end
