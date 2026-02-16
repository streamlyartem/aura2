# frozen_string_literal: true

class InsalesMediaSyncState < ApplicationRecord
  self.implicit_order_column = :created_at

  belongs_to :product

  STATUSES = %w[success in_progress error].freeze

  validates :product_id, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
end
