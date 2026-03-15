# frozen_string_literal: true

module Insales
  class OrdersFeed
    DEFAULT_PER_PAGE = 50

    Result = Struct.new(:orders, :error, :page, :per_page, keyword_init: true)

    def initialize(client: InsalesClient.new)
      @client = client
    end

    def call(page: 1, per_page: DEFAULT_PER_PAGE, query: nil, sku: nil)
      response = @client.get('/admin/orders.json', { page: page.to_i, per_page: per_page.to_i })
      return Result.new(orders: [], error: "HTTP #{response.status}", page: page, per_page: per_page) unless response.status.to_i.between?(200, 299)

      orders = extract_orders(response.body).map { |order| normalize_order(order) }
      orders = filter_by_query(orders, query)
      orders = filter_by_sku(orders, sku)

      Result.new(orders: orders, error: nil, page: page.to_i, per_page: per_page.to_i)
    rescue StandardError => e
      Rails.logger.warn("[InSalesOrders] load failed: #{e.class} #{e.message}")
      Result.new(orders: [], error: "#{e.class}: #{e.message}", page: page.to_i, per_page: per_page.to_i)
    end

    private

    def extract_orders(body)
      case body
      when Array
        body
      when Hash
        body['orders'] || []
      else
        []
      end
    end

    def normalize_order(order)
      lines = Array(order['order_lines'] || order['lines'] || order['items'])
      skus = lines.filter_map do |line|
        line['sku'] || line.dig('variant', 'sku') || line.dig('product', 'sku')
      end.compact.map(&:to_s).uniq

      {
        id: order['id'],
        number: order['number'] || order['order_number'] || order['key'],
        created_at: order['created_at'],
        updated_at: order['updated_at'],
        status: order['status'] || order['state'],
        financial_status: order['financial_status'],
        fulfillment_status: order['fulfillment_status'] || order['delivery_status'],
        total_price: order['total_price'] || order['total_price_with_discount'],
        currency: order['currency_code'] || order['currency'],
        client_name: order.dig('client', 'name') || order['client_name'],
        client_email: order.dig('client', 'email') || order['email'],
        client_phone: order.dig('client', 'phone') || order['phone'],
        skus: skus
      }
    end

    def filter_by_query(orders, query)
      q = query.to_s.strip.downcase
      return orders if q.blank?

      orders.select do |order|
        [order[:id], order[:number], order[:client_name], order[:client_email], order[:status], order[:financial_status], order[:fulfillment_status]]
          .compact
          .any? { |value| value.to_s.downcase.include?(q) }
      end
    end

    def filter_by_sku(orders, sku)
      query = sku.to_s.strip.downcase
      return orders if query.blank?

      orders.select { |order| order[:skus].any? { |value| value.to_s.downcase.include?(query) } }
    end
  end
end
