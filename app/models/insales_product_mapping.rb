# frozen_string_literal: true

class InsalesProductMapping < ApplicationRecord
  self.implicit_order_column = :created_at

  belongs_to :product, foreign_key: :aura_product_id, inverse_of: false

  validates :aura_product_id, presence: true, uniqueness: true
  validates :insales_product_id, presence: true, uniqueness: true
end
