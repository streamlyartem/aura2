# frozen_string_literal: true

module Insales
  class SyncProductTriggerJob < ApplicationJob
    queue_as :default

    retry_on Faraday::TimeoutError, Faraday::ConnectionFailed, wait: :exponentially_longer, attempts: 3

    def perform(product_id:, reason: nil)
      with_product_lock(product_id) do
        result = Insales::SyncProductTrigger.new.call(product_id: product_id, reason: reason)
        Rails.logger.info(
          "[InSalesSync][TriggerJob] product=#{product_id} reason=#{reason} status=#{result.status} action=#{result.action} message=#{result.message}"
        )
      end
    end

    private

    def with_product_lock(product_id)
      lock_key = "insales:trigger:product:#{product_id}"
      obtained = Rails.cache.write(lock_key, true, unless_exist: true, expires_in: 2.minutes)
      return unless obtained

      yield
    ensure
      Rails.cache.delete(lock_key) if obtained
    end
  end
end
