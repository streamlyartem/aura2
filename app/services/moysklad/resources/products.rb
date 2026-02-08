# frozen_string_literal: true

module Moysklad
  module Resources
    # Products resource for Moysklad API
    class Products < Base
      def entity_path
        'entity/product'
      end

      def each(limit: 1000, &)
        each_resource(limit: limit, &)
      end

      # Public wrapper for find method
    end
  end
end
