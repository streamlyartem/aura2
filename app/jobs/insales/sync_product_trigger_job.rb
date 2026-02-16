# frozen_string_literal: true

require 'zlib'

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
      key = advisory_lock_key(product_id)

      ActiveRecord::Base.connection_pool.with_connection do |connection|
        obtained = connection.select_value("SELECT pg_try_advisory_lock(#{key}::bigint)")
        unless obtained
          Rails.logger.info("[InSalesSync][TriggerJob] skip product=#{product_id} reason=lock_not_acquired")
          return
        end

        yield
      ensure
        connection.execute("SELECT pg_advisory_unlock(#{key}::bigint)") if obtained
      end
    end

    def advisory_lock_key(product_id)
      namespace = 42_017
      crc = Zlib.crc32(product_id.to_s)
      value = ((namespace & 0xffffffff) << 32) | (crc & 0xffffffff)
      value > 0x7fffffffffffffff ? value - 0x10000000000000000 : value
    end
  end
end
