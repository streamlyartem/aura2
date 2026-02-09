# frozen_string_literal: true

module Moysklad
  class EnsureWebhooksJob < ApplicationJob
    queue_as :default

    def perform
      result = Moysklad::Webhooks::Registrar.new.ensure!
      Rails.logger.info("[MoySkladWebhooks] Result created=#{result.created} skipped=#{result.skipped} errors=#{result.errors}")
    end
  end
end
