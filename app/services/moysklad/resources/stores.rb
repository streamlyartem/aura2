# frozen_string_literal: true

module Moysklad
  module Resources
    # Stores resource for Moysklad API
    class Stores < Base
      def entity_path
        'entity/store'
      end

      def each(limit: 1000, &)
        each_resource(limit: limit, &)
      end
    end
  end
end
