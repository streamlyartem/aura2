# frozen_string_literal: true

class PriceType < ApplicationRecord
  has_many :variant_prices, dependent: :destroy

  validates :code, presence: true, uniqueness: true
  validates :currency, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[code created_at currency id ms_price_type_id updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[variant_prices]
  end
end
