# frozen_string_literal: true

class MoyskladStore < ApplicationRecord
  scope :selected, -> { where(selected_for_import: true) }

  validates :name, presence: true, uniqueness: true

  def self.refresh_from_moysklad!(client: MoyskladClient.new)
    names = Array(client.store_names).map(&:to_s).map(&:strip).reject(&:blank?).uniq.sort
    now = Time.current

    names.each do |name|
      record = find_or_initialize_by(name: name)
      record.last_seen_at = now
      record.save!
    end

    names
  end

  def self.enqueue_stock_counts_refresh!(store_names: nil)
    relation = if store_names.present?
                 where(name: store_names)
               else
                 all
               end

    relation.find_each do |store|
      Moysklad::RefreshStoreStockCountsJob.perform_later(store.id)
    end
  end

  def self.fetch_store_counts(client:, store_name:)
    rows = client.stocks_for_store(store_name: store_name, positive_only: false)

    {
      total_products_count: rows.size,
      nonzero_products_count: rows.count { |row| row[:stock].to_f.positive? }
    }
  rescue StandardError => e
    Rails.logger.warn("[MoyskladStore] Failed to refresh counts for store=#{store_name}: #{e.class} - #{e.message}")

    {
      total_products_count: nil,
      nonzero_products_count: nil
    }
  end

  def refresh_stock_counts!(client: MoyskladClient.new)
    counts = self.class.fetch_store_counts(client: client, store_name: name)

    update!(
      total_products_count: counts[:total_products_count],
      nonzero_products_count: counts[:nonzero_products_count],
      stock_stats_synced_at: Time.current
    )
  end

  def self.selected_names
    selected.order(:name).pluck(:name)
  end

  def self.all_names
    order(:name).pluck(:name)
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at id last_seen_at name nonzero_products_count selected_for_import stock_stats_synced_at total_products_count updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
