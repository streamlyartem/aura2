# frozen_string_literal: true

module Moysklad
  module Resources
    # Base class for Moysklad API resources
    class Base
      attr_reader :http_client

      def initialize(http_client)
        @http_client = http_client
      end

      protected

      def entity_path
        raise NotImplementedError, "#{self.class} must implement #entity_path"
      end

      def each_resource(limit: 1000, &)
        return enum_for(:each_resource, limit: limit) unless block_given?

        offset = 0

        loop do
          response = http_client.get(entity_path, limit: limit, offset: offset)

          rows = response.body.fetch('rows', [])
          break if rows.empty?

          rows.each(&)

          offset += limit
        end
      end

      def find(id)
        response = http_client.get("#{entity_path}/#{id}")
        response.body
      end

      public :find
    end
  end
end
