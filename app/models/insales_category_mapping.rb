# frozen_string_literal: true

class InsalesCategoryMapping < ApplicationRecord
  validates :product_type, presence: true
  validates :insales_category_id, presence: true

  def specificity_score
    score = 0
    score += 1 if tone.present?
    score += 1 if length.present?
    score += 1 unless ombre.nil?
    score += 1 if structure.present?
    score
  end
end
