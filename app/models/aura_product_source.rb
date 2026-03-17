# frozen_string_literal: true

class AuraProductSource < ApplicationRecord
  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:priority, :name) }

  validates :code, :name, :source_kind, presence: true
  validates :code, uniqueness: true

  before_validation :normalize_fields
  before_validation :normalize_settings

  def self.ransackable_attributes(_auth_object = nil)
    %w[active authoritative code created_at id name priority settings source_kind updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  private

  def normalize_fields
    self.code = code.to_s.strip.downcase.presence
    self.name = name.to_s.strip.presence
    self.source_kind = source_kind.to_s.strip.downcase.presence
    self.settings = {} if settings.blank?
  end

  def normalize_settings
    return if settings.blank? || settings.is_a?(Hash)

    self.settings = JSON.parse(settings.to_s)
  rescue JSON::ParserError
    errors.add(:settings, 'должен быть валидным JSON')
  end
end
