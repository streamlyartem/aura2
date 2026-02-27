# frozen_string_literal: true

class Product < ApplicationRecord
  self.implicit_order_column = :created_at

  has_many :images, dependent: :destroy, as: :object
  has_many :product_stocks, dependent: :destroy
  after_commit :enqueue_insales_sync_trigger, on: %i[create update]

  accepts_nested_attributes_for :images, allow_destroy: true

  # after_commit :sync_to_moysklad, on: %i[create update]

  def self.ransackable_attributes(_auth_object = nil)
    %w[id name sku created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  def self.find_by_scanned_barcode(raw_value)
    candidates = barcode_candidates(raw_value)
    return nil if candidates.empty?

    product = where(sku: candidates).or(where(code: candidates)).first
    return product if product

    like_conditions = candidates.map { 'barcodes::text LIKE ?' }.join(' OR ')
    like_values = candidates.map { |candidate| "%#{candidate}%" }

    where.not(barcodes: [])
         .where([like_conditions, *like_values])
         .find do |candidate_product|
      barcode_intersection?(candidate_product, candidates)
    end
  end

  def self.barcode_candidates(raw_value)
    value = raw_value.to_s.strip
    return [] if value.blank?

    digits = value.gsub(/\D/, '')
    candidates = [value, digits].reject(&:blank?)
    candidates << digits.sub(/\A0+/, '') if digits.present?
    candidates.uniq
  end

  def self.barcode_intersection?(product, candidates)
    candidate_set = candidates.to_set
    normalized_candidate_set = candidates
                               .map { |candidate| candidate.to_s.gsub(/\D/, '').sub(/\A0+/, '') }
                               .reject(&:blank?)
                               .to_set

    values = [product.sku, product.code, *extract_barcode_values(product)]
             .compact
             .map(&:to_s)
             .reject(&:blank?)

    values.any? do |value|
      normalized = value.gsub(/\D/, '')
      stripped = normalized.sub(/\A0+/, '')

      candidate_set.include?(value) ||
        candidate_set.include?(normalized) ||
        candidate_set.include?(stripped) ||
        normalized_candidate_set.include?(stripped)
    end
  end

  def self.extract_barcode_values(product)
    barcodes = Array(product.barcodes)
    barcodes.flat_map do |entry|
      case entry
      when Hash
        entry.values
      else
        entry
      end
    end
  end

  private

  def enqueue_insales_sync_trigger
    return if id.blank?
    return if Current.skip_insales_product_sync?
    return if previous_changes.except('updated_at').blank?

    Insales::SyncProductTriggerJob.perform_later(product_id: id, reason: 'product_changed')
  end

  def sync_to_moysklad
    return unless Rails.env.production? || Rails.env.development?
    return if ms_id.blank? # чтобы не пытаться синкать не связанные товары

    MoyskladClient.new.update_product_in_ms(self)
  rescue StandardError => e
    Rails.logger.error "[MoyskladSync] Failed to sync product #{id}: #{e.message}"
  end
end
