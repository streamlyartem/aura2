# frozen_string_literal: true

class PricingRuleset < ApplicationRecord
  has_many :pricing_tiers, -> { order(priority: :desc, min_eligible_weight_g: :asc) }, dependent: :destroy

  validates :channel, :name, presence: true

  scope :active, -> { where(is_active: true) }

  def self.ransackable_attributes(_auth_object = nil)
    %w[channel created_at id is_active name updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[pricing_tiers]
  end
end
