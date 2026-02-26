# frozen_string_literal: true

class PricingTier < ApplicationRecord
  belongs_to :pricing_ruleset

  validates :min_eligible_weight_g, :price_type_code, presence: true
  validates :priority, numericality: { only_integer: true }
  validate :max_not_less_than_min

  scope :ordered, -> { order(priority: :desc, min_eligible_weight_g: :asc) }

  def matches_weight?(weight_g)
    grams = weight_g.to_i
    return false if grams < min_eligible_weight_g.to_i
    return true if max_eligible_weight_g.nil?

    grams <= max_eligible_weight_g.to_i
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at id max_eligible_weight_g min_eligible_weight_g price_type_code pricing_ruleset_id priority updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[pricing_ruleset]
  end

  private

  def max_not_less_than_min
    return if max_eligible_weight_g.nil?
    return if max_eligible_weight_g >= min_eligible_weight_g

    errors.add(:max_eligible_weight_g, 'must be greater than or equal to min_eligible_weight_g')
  end
end
