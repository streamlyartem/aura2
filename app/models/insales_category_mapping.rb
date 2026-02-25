# frozen_string_literal: true

class InsalesCategoryMapping < ApplicationRecord
  validates :product_type, presence: true, unless: :path_mapping?
  validates :insales_category_id, presence: true
  validates :aura_key, presence: true, if: :path_mapping?
  validates :aura_key_type, presence: true, if: :path_mapping?
  validates :aura_key, uniqueness: { scope: :aura_key_type }, allow_blank: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[id product_type tone length ombre structure insales_category_id aura_key aura_key_type insales_collection_title comment is_active created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  def specificity_score
    score = 0
    score += 1 if tone.present?
    score += 1 if length.present?
    score += 1 unless ombre.nil?
    score += 1 if structure.present?
    score
  end

  def path_mapping?
    aura_key_type.to_s.casecmp('path').zero?
  end
end
