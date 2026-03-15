# frozen_string_literal: true

module Insales
  module ApiV1
    module FeatureFlags
      module_function

      def read_enabled?
        enabled_env?('INSALES_API_V1_READ_ENABLED', default: true)
      end

      def write_enabled?
        enabled_env?('INSALES_API_V1_WRITE_ENABLED', default: false)
      end

      def outbox_enabled?
        enabled_env?('INSALES_OUTBOX_ENABLED', default: true)
      end

      def full_sync_enabled?
        enabled_env?('INSALES_API_V1_FULL_SYNC_ENABLED', default: true)
      end

      def auth_token
        ENV['INSALES_API_V1_TOKEN'].to_s
      end

      def enabled_env?(key, default:)
        raw = ENV[key]
        return default if raw.nil?

        ActiveModel::Type::Boolean.new.cast(raw)
      end
    end
  end
end
