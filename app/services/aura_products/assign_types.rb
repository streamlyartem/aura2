# frozen_string_literal: true

module AuraProducts
  class AssignTypes
    BATCH_SIZE = 500

    Result = Struct.new(:processed, :updated, keyword_init: true)

    def self.call(...)
      new.call(...)
    end

    def call(scope: Product.all)
      resolver = AuraProducts::TypeResolver.new
      result = Result.new(processed: 0, updated: 0)

      scope.select(:id, :path_name, :unit_type, :aura_product_type_id).in_batches(of: BATCH_SIZE) do |batch|
        batch.to_a.each do |product|
          result.processed += 1
          type_id = resolver.resolve(product)&.id
          next if product.aura_product_type_id == type_id

          product.update_columns(aura_product_type_id: type_id, updated_at: Time.current)
          result.updated += 1
        end
      end

      result
    end
  end
end
