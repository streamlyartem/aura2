# frozen_string_literal: true

module Insales
  module StockChangeEvents
    class PriorityResolver
      Result = Struct.new(:priority, :reason, keyword_init: true)

      def initialize(setting: InsalesSetting.first)
        @setting = setting
      end

      def call(store_name:, new_stock:, price_impact: false)
        return Result.new(priority: "high", reason: "nonpositive_stock") if new_stock.to_d <= 0
        return Result.new(priority: "high", reason: "selling_store") if selling_store?(store_name)
        return Result.new(priority: "high", reason: "price_impact") if price_impact

        Result.new(priority: "normal", reason: "stock_changed")
      end

      private

      attr_reader :setting

      def selling_store?(store_name)
        return false if store_name.blank?

        selling_store_names.include?(store_name.to_s.strip)
      end

      def selling_store_names
        @selling_store_names ||= begin
          names = setting&.allowed_store_names_list
          names = [MoyskladClient::TEST_STORE_NAME] if names.blank?
          names
        end
      end
    end
  end
end
