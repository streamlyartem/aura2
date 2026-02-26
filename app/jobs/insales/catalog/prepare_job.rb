# frozen_string_literal: true

module Insales
  module Catalog
    class PrepareJob < ApplicationJob
      queue_as :default

      def perform
        result = Insales::Catalog::Prepare.call
        Rails.logger.info(
          "[InSalesCatalog] Prepare finished processed=#{result.processed} ready=#{result.ready} " \
          "skipped=#{result.skipped} errors=#{result.errors}"
        )
      end
    end
  end
end
