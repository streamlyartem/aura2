# frozen_string_literal: true

class InsalesMediaStatus < ApplicationRecord
  self.implicit_order_column = :created_at

  belongs_to :product

  STATUSES = %w[success in_progress error].freeze

  validates :product_id, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
end
