# frozen_string_literal: true

module AuraProducts
  class AssignTypesJob < ApplicationJob
    queue_as :default

    def perform
      result = AuraProducts::AssignTypes.call
      Rails.logger.info("[AuraProducts][AssignTypes] processed=#{result.processed} updated=#{result.updated}")
    end
  end
end
