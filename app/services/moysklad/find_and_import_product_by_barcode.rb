# frozen_string_literal: true

require 'cgi'

module Moysklad
  class FindAndImportProductByBarcode
    SEARCH_LIMIT = 100

    def self.call(raw_value:, client: MoyskladClient.new)
      new(client).call(raw_value: raw_value)
    end

    def initialize(client)
      @client = client
    end

    def call(raw_value:)
      candidates = ::Product.barcode_candidates(raw_value)
      return nil if candidates.empty?

      payload = find_payload(candidates)
      return nil if payload.blank?

      Current.set(skip_insales_product_sync: true) do
        upsert_product(payload)
      end
    rescue StandardError => e
      Rails.logger.warn("[Moysklad][ScanImport] failed barcode=#{raw_value} error=#{e.class} #{e.message}")
      nil
    end

    private

    attr_reader :client

    def find_payload(candidates)
      candidates.each do |candidate|
        rows = search_products(candidate)
        match = rows.find { |row| payload_matches_candidates?(row, candidates) }
        return match if match
      end

      nil
    end

    def search_products(query)
      response = client.get_full("entity/product?search=#{CGI.escape(query)}&limit=#{SEARCH_LIMIT}")
      body = response.respond_to?(:body) ? response.body : response
      return body.fetch('rows', []) if body.is_a?(Hash)
      return body if body.is_a?(Array)

      []
    rescue StandardError => e
      Rails.logger.warn("[Moysklad][ScanImport] search failed query=#{query} error=#{e.class} #{e.message}")
      []
    end

    def payload_matches_candidates?(payload, candidates)
      candidate_set = candidates.to_set
      normalized_candidate_set = candidates
                                 .map { |value| normalize_digits(value) }
                                 .reject(&:blank?)
                                 .to_set

      payload_values(payload).any? do |value|
        normalized = value.to_s.gsub(/\D/, '')
        stripped = normalize_digits(value)

        candidate_set.include?(value.to_s) ||
          candidate_set.include?(normalized) ||
          candidate_set.include?(stripped) ||
          normalized_candidate_set.include?(stripped)
      end
    end

    def payload_values(payload)
      barcode_values = Array(payload['barcodes']).flat_map do |entry|
        case entry
        when Hash then entry.values
        else entry
        end
      end

      [payload['article'], payload['code'], *barcode_values]
        .compact
        .map(&:to_s)
        .reject(&:blank?)
    end

    def normalize_digits(value)
      value.to_s.gsub(/\D/, '').sub(/\A0+/, '')
    end

    def upsert_product(ms_product_payload)
      ms_product = Moysklad::Product.new(ms_product_payload)

      product = ::Product.find_or_initialize_by(ms_id: ms_product.id)
      product.assign_attributes(
        ms_id: ms_product.id,
        name: ms_product.name,
        batch_number: ms_product.batch_number,
        path_name: ms_product.path_name,
        weight: ms_product.weight&.to_f,
        length: ms_product.length&.to_f,
        color: ms_product.color,
        tone: ms_product.tone,
        ombre: ms_product.ombre.nil? ? false : ms_product.ombre,
        structure: ms_product.structure,
        sku: ms_product.sku,
        code: ms_product.code,
        barcodes: ms_product.barcodes,
        purchase_price: ms_product.purchase_price&.to_f,
        retail_price: ms_product.retail_price&.to_f,
        small_wholesale_price: ms_product.small_wholesale_price&.to_f,
        large_wholesale_price: ms_product.large_wholesale_price&.to_f,
        five_hundred_plus_wholesale_price: ms_product.five_hundred_plus_wholesale_price&.to_f,
        min_price: ms_product.min_price&.to_f
      )
      product.save!
      product
    end
  end
end
