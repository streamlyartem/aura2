# frozen_string_literal: true

module Moysklad
  module Resources
    # Stocks resource for Moysklad API
    class Stocks < Base
      DEFAULT_PAGE_LIMIT = 1_000

      def entity_path
        'report/stock/all'
      end

      def for_store(store_href, limit: DEFAULT_PAGE_LIMIT)
        offset = 0
        rows = []

        loop do
          response = http_client.get(entity_path, filter: "store=#{store_href}", limit: limit, offset: offset)
          body = response.body || {}
          page_rows = body['rows'] || []
          break if page_rows.empty?

          rows.concat(page_rows)
          offset += limit

          total = body.dig('meta', 'size').to_i
          break if total.positive? && offset >= total
        end

        rows.select { |row| row['stock'].to_f.positive? }
      end
    end
  end
end
