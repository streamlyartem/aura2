# frozen_string_literal: true

class VariantPrice < ApplicationRecord
  belongs_to :variant, class_name: 'Product', foreign_key: :variant_id
  belongs_to :price_type

  validates :variant_id, presence: true
  validates :price_type_id, presence: true
  validates :variant_id, uniqueness: { scope: :price_type_id }

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at id price_per_g_cents price_per_piece_cents price_type_id updated_at variant_id]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[price_type variant]
  end
end
