# frozen_string_literal: true

module Insales
  class SyncStoreJob < ApplicationJob
    queue_as :default

    def perform(store_name:, collection_id: nil, update_product_fields: false, sync_images: false)
      result = Insales::SyncStore.new.call(
        store_name: store_name,
        collection_id: collection_id,
        update_product_fields: update_product_fields,
        sync_images: sync_images
      )

      Rails.cache.write(
        cache_key(store_name),
        result.to_h.merge(updated_at: Time.current),
        expires_in: 6.hours
      )
    end

    private

    def cache_key(store_name)
      "insales_sync_status:#{store_name}"
    end
  end
end
