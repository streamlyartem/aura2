# frozen_string_literal: true

class InsalesMediaStatusItem < ApplicationRecord
  self.implicit_order_column = :created_at

  belongs_to :product

  KINDS = %w[image video].freeze
  STATUSES = %w[success in_progress error].freeze

  validates :product_id, :source_key, :kind, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :source_key, uniqueness: { scope: :product_id }
end
