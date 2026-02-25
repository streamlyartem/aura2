# frozen_string_literal: true

module Moysklad
  class Product
    attr_reader :id, :name, :batch_number, :path_name, :weight, :length, :color, :tone, :ombre,
                :structure, :sku, :code, :barcodes, :purchase_price, :retail_price, :small_wholesale_price,
                :large_wholesale_price, :five_hundred_plus_wholesale_price, :min_price

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
      @purchase_price = normalize_price(ms_product_payload.dig('buyPrice', 'value'))
      @retail_price = extract_price(sale_prices, 'Цена продажи')
      @small_wholesale_price = extract_price(sale_prices, 'мелкий опт')
      @large_wholesale_price = extract_price(sale_prices, 'крупный опт')
      @five_hundred_plus_wholesale_price = extract_price(sale_prices, 'Опт 500+')
      @min_price = normalize_price(ms_product_payload.dig('minPrice', 'value'))
    end

    private

    def extract_price(sale_prices, price_name)
      raw = sale_prices.find { |price| price.dig('priceType', 'name') == price_name }&.dig('value')
      normalize_price(raw)
    end

    def normalize_price(value)
      return nil if value.nil?

      value.to_f / 100.0
    end
  end
end
