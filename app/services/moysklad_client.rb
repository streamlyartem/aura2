# frozen_string_literal: true

# Main client for interacting with Moysklad API
# Provides a high-level interface delegating to specialized resource classes
class MoyskladClient
  BASE_URL = Moysklad::Config::BASE_URL
  TEST_STORE_NAME = 'Тест'

  TEST_STORE_META = {
    'href' => 'https://api.moysklad.ru/api/remap/1.2/entity/store/d2a971ca-9164-11f0-0a80-19cb0021b994',
    'metadataHref' => 'https://api.moysklad.ru/api/remap/1.2/entity/store/metadata',
    'type' => 'store',
    'mediaType' => 'application/json',
    'uuidHref' => 'https://online.moysklad.ru/app/#warehouse/edit?id=d2a971ca-9164-11f0-0a80-19cb0021b994'
  }.freeze

  TEST_NAMES_HREF = {
    TEST_STORE_NAME => 'https://api.moysklad.ru/api/remap/1.2/entity/store/d2a971ca-9164-11f0-0a80-19cb0021b994'
  }.freeze

  attr_reader :config, :http_client, :products, :demands, :stocks, :stores

  def initialize(username: ENV.fetch('MOYSKLAD_USER', nil), password: ENV.fetch('MOYSKLAD_PASS', nil),
                 base_url: BASE_URL)
    @config = build_config(username, password, base_url)
    @http_client = Moysklad::HttpClient.new(@config)
    @products = Moysklad::Resources::Products.new(@http_client)
    @demands = Moysklad::Resources::Demands.new(@http_client)
    @stocks = Moysklad::Resources::Stocks.new(@http_client)
    @stores = Moysklad::Resources::Stores.new(@http_client)
  rescue Moysklad::HttpClient::Error => e
    Rails.logger.error "[MoyskladClient] Initialization error: #{e.message}"
    raise
  end

  # Delegates to http_client for backward compatibility
  delegate :get_full, to: :http_client

  # Delegates to products resource
  def each_product(limit: 1000, &)
    products.each(limit: limit, &)
  end

  def product(id)
    products.find(id)
  end

  # Business logic method - transforms stock data into a more usable format
  def stocks_for_store(store_name: TEST_STORE_NAME)
    store_href = store_href_map[store_name]
    raise ArgumentError, "Unknown store: #{store_name}" unless store_href

    rows = stocks.for_store(store_href)

    products_data = rows.map do |row|
      {
        code: row['code'],
        article: row['article'],
        stock: row['stock'],
        free_stock: row['freeStock'],
        reserve: row['reserve'],
        product_meta: row['meta'],
        store_name: store_name
      }
    end

    Rails.logger.debug { "[MoyskladClient] Found #{products_data.size} products at store '#{store_name}'" }
    products_data
  end

  def stores_list(limit: 1000)
    if Rails.env.test?
      return store_href_map.map { |name, href| { 'name' => name, 'href' => href } }
    end

    stores.each(limit: limit).map do |store|
      {
        'name' => store['name'],
        'href' => store.dig('meta', 'href')
      }
    end
  end

  def store_names
    store_href_map.keys
  end

  def store_href_map
    return TEST_NAMES_HREF if Rails.env.test?

    Rails.cache.fetch('moysklad:store_hrefs', expires_in: 15.minutes) do
      map = {}
      stores.each(limit: 1000) do |store|
        name = store['name'].to_s.strip
        href = store.dig('meta', 'href')
        next if name.blank? || href.blank?

        map[name] = href
      end

      map.presence || TEST_NAMES_HREF
    end
  rescue StandardError => e
    Rails.logger.warn "[MoyskladClient] Fetch stores failed: #{e.class} - #{e.message}"
    TEST_NAMES_HREF
  end

  # Business logic method - creates a demand for a product write-off
  def create_demand(product, stock)
    Rails.logger.debug { "[MoyskladClient] Create demand for #{product.name} in amount #{stock}" }

    position = {
      quantity: stock,
      assortment: {
        meta: {
          href: "#{config.base_url}/entity/product/#{product.ms_id}",
          type: 'product',
          mediaType: 'application/json'
        }
      }
    }

    Rails.logger.debug { "[MoyskladClient] Create demand for product #{product.ms_id}, quantity #{stock}" }

    demands.create(
      organization_meta: config.default_org_meta,
      agent_meta: config.default_agent_meta,
      store_meta: config.default_store_meta,
      positions: [position]
    )
  end

  private

  def build_config(username, password, base_url)
    config = Moysklad::Config.new
    # Override defaults only if explicitly provided (not nil)
    config.username = username if username
    config.password = password if password
    # Special handling for base_url: nil means use default, non-nil means override
    config.base_url = base_url if base_url && base_url != BASE_URL
    config
  end
end
