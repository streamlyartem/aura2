# frozen_string_literal: true

class InsalesImageMapping < ApplicationRecord
  self.implicit_order_column = :created_at

  belongs_to :image, foreign_key: :aura_image_id, inverse_of: false

  validates :aura_image_id, presence: true, uniqueness: true
  validates :insales_image_id, uniqueness: true, allow_nil: true
  validates :insales_product_id, presence: true
end
