# frozen_string_literal: true

module Moysklad
  module Resources
    # Stocks resource for Moysklad API
    class Stocks < Base
      def entity_path
        'report/stock/all'
      end

      def for_store(store_href)
        response = http_client.get(entity_path, filter: "store=#{store_href}")

        rows = response.body['rows'] || []
        rows.select { |row| row['stock'].to_f.positive? }
      end
    end
  end
end
