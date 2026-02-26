# frozen_string_literal: true

module Moysklad
  class Product
    attr_reader :id, :name, :batch_number, :path_name, :weight, :length, :color, :tone, :ombre,
                :structure, :sku, :code, :barcodes, :purchase_price, :retail_price, :small_wholesale_price,
                :large_wholesale_price, :five_hundred_plus_wholesale_price, :min_price, :purchase_price_per_g_cents,
                :retail_price_per_g_cents, :small_wholesale_price_per_g_cents, :big_wholesale_price_per_g_cents,
                :wholesale_500_plus_price_per_g_cents

    PRICE_TYPE_NAME_MAP = {
      'retail' => 'Цена продажи',
      'small_wholesale' => 'мелкий опт',
      'big_wholesale' => 'крупный опт',
      'wholesale_500_plus' => 'Опт 500+'
    }.freeze

    def initialize(ms_product_payload)
      attributes = ms_product_payload['attributes']
      sale_prices = Array(ms_product_payload['salePrices'])
      ms_product_payload.dig('meta', 'uuidHref')

      @id = ms_product_payload['id']
      @name = ms_product_payload['name']
      @batch_number = attributes.find { |attribute| attribute['name'] == 'Партия' }&.dig('value')
      @path_name = ms_product_payload['pathName']
      @weight = ms_product_payload['weight']
      @length = attributes.find { |attribute| attribute['name'] == 'Длина' }&.dig('value')
      @color = attributes.find { |attribute| attribute['name'] == 'Цвет' }&.dig('value')
      @tone = attributes.find { |attribute| attribute['name'] == 'Тон' }&.dig('value', 'name')
      @ombre = attributes.find { |attribute| attribute['name'] == 'Омбре' }&.dig('value')
      @structure = attributes.find { |attribute| attribute['name'] == 'Структура' }&.dig('value', 'name')
      @sku = ms_product_payload['article']
      @code = ms_product_payload['code']
      @barcodes = ms_product_payload['barcodes']
      @purchase_price_per_g_cents = normalize_cents(ms_product_payload.dig('buyPrice', 'value'))
      @purchase_price = cents_per_g_to_bundle_price(@purchase_price_per_g_cents)

      @retail_price_per_g_cents = extract_price_cents(sale_prices, PRICE_TYPE_NAME_MAP['retail'])
      @small_wholesale_price_per_g_cents = extract_price_cents(sale_prices, PRICE_TYPE_NAME_MAP['small_wholesale'])
      @big_wholesale_price_per_g_cents = extract_price_cents(sale_prices, PRICE_TYPE_NAME_MAP['big_wholesale'])
      @wholesale_500_plus_price_per_g_cents = extract_price_cents(sale_prices, PRICE_TYPE_NAME_MAP['wholesale_500_plus'])

      @retail_price = cents_per_g_to_bundle_price(@retail_price_per_g_cents)
      @small_wholesale_price = cents_per_g_to_bundle_price(@small_wholesale_price_per_g_cents)
      @large_wholesale_price = cents_per_g_to_bundle_price(@big_wholesale_price_per_g_cents)
      @five_hundred_plus_wholesale_price = cents_per_g_to_bundle_price(@wholesale_500_plus_price_per_g_cents)
      @min_price = normalize_price(ms_product_payload.dig('minPrice', 'value'), per_gram: true)
    end

    private

    def extract_price(sale_prices, price_name)
      raw = sale_prices.find { |price| price.dig('priceType', 'name') == price_name }&.dig('value')
      normalize_price(raw, per_gram: true)
    end

    def extract_price_cents(sale_prices, price_name)
      raw = sale_prices.find { |price| price.dig('priceType', 'name') == price_name }&.dig('value')
      normalize_cents(raw)
    end

    def normalize_price(value, per_gram: false)
      return nil if value.nil?

      price = value.to_f / 100.0
      return price unless per_gram

      (price * weight_grams).round(2)
    end

    def normalize_cents(value)
      return nil if value.nil?

      value.to_i
    end

    def cents_per_g_to_bundle_price(cents)
      return nil if cents.nil?

      ((cents.to_i / 100.0) * weight_grams).round(2)
    end

    def weight_grams
      @weight.to_f
    end
  end
end
