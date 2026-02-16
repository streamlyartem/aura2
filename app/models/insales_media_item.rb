# frozen_string_literal: true

require 'digest'

class InsalesMediaItem < ApplicationRecord
  KINDS = %w[image video].freeze
  SOURCE_TYPES = %w[image url].freeze

  belongs_to :product, foreign_key: :aura_product_id
  belongs_to :image, foreign_key: :aura_image_id, optional: true

  validates :aura_product_id, :kind, :position, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :source_type, inclusion: { in: SOURCE_TYPES }
  validates :position, numericality: { only_integer: true, greater_than: 0 }

  before_validation :assign_checksum
  validate :source_presence

  def self.ransackable_attributes(_auth_object = nil)
    %w[aura_product_id kind source_type aura_image_id url position export_to_insales checksum created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[image product]
  end

  private

  def assign_checksum
    self.checksum = if kind == 'image'
                      image_checksum
                    elsif kind == 'video'
                      url_checksum
                    end
  end

  def image_checksum
    return nil unless image&.file&.attached?

    image.file.blob&.checksum
  end

  def url_checksum
    return nil if url.blank?

    Digest::SHA256.hexdigest(url.to_s)
  end

  def source_presence
    if kind == 'image' && aura_image_id.blank?
      errors.add(:aura_image_id, 'is required for image')
    elsif kind == 'video' && url.blank?
      errors.add(:url, 'is required for video')
    end
  end
end
