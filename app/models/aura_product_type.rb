# frozen_string_literal: true

class AuraProductType < ApplicationRecord
  UNIT_TYPES = %w[weight piece].freeze

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:priority, :name) }

  validates :code, :name, presence: true
  validates :code, uniqueness: true
  validates :matcher_unit_type, inclusion: { in: UNIT_TYPES }, allow_blank: true

  before_validation :normalize_fields

  def self.ransackable_attributes(_auth_object = nil)
    %w[active code created_at description id matcher_path_prefix matcher_unit_type name priority updated_at weight_from_stock]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  def matches?(product)
    return false if product.blank?
    return false if matcher_unit_type.blank? && matcher_path_prefix.blank?
    return false if matcher_unit_type.present? && product.unit_type.to_s != matcher_unit_type

    if matcher_path_prefix.present?
      path = product.path_name.to_s.strip
      return false if path.blank?

      return false unless path.downcase.start_with?(matcher_path_prefix.downcase)
    end

    true
  end

  private

  def normalize_fields
    self.code = code.to_s.strip.downcase.presence
    self.name = name.to_s.strip.presence
    self.matcher_path_prefix = matcher_path_prefix.to_s.strip.presence
    self.matcher_unit_type = matcher_unit_type.to_s.strip.presence
  end
end
