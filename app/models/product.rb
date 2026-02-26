# frozen_string_literal: true

class Product < ApplicationRecord
  self.implicit_order_column = :created_at

  has_many :images, dependent: :destroy, as: :object
  has_many :product_stocks, dependent: :destroy
  has_many :variant_prices, foreign_key: :variant_id, dependent: :destroy
  after_commit :enqueue_insales_sync_trigger, on: %i[create update]

  accepts_nested_attributes_for :images, allow_destroy: true

  # after_commit :sync_to_moysklad, on: %i[create update]

  def self.ransackable_attributes(_auth_object = nil)
    %w[id name sku code unit_type unit_weight_g ms_stock_g ms_stock_qty created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[variant_prices]
  end

  validates :unit_type, inclusion: { in: %w[weight piece] }
  validate :unit_weight_required_for_weight

  def weight_unit?
    unit_type == 'weight'
  end

  def piece_unit?
    unit_type == 'piece'
  end

  private

  def enqueue_insales_sync_trigger
    return if id.blank?
    return if Current.skip_insales_product_sync?
    return if previous_changes.except('updated_at').blank?

    Insales::SyncProductTriggerJob.perform_later(product_id: id, reason: 'product_changed')
  end

  def unit_weight_required_for_weight
    return unless weight_unit?
    return if unit_weight_g.present? && unit_weight_g.to_d.positive?

    errors.add(:unit_weight_g, 'must be present and positive for weight unit type')
  end

  def sync_to_moysklad
    return unless Rails.env.production? || Rails.env.development?
    return if ms_id.blank? # чтобы не пытаться синкать не связанные товары

    MoyskladClient.new.update_product_in_ms(self)
  rescue StandardError => e
    Rails.logger.error "[MoyskladSync] Failed to sync product #{id}: #{e.message}"
  end
end
