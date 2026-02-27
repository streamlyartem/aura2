# frozen_string_literal: true

class InsalesCatalogItem < ApplicationRecord
  STATUSES = %w[ready skipped error].freeze

  belongs_to :product

  validates :product_id, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :ready, -> { where(status: 'ready') }
  scope :skipped, -> { where(status: 'skipped') }
  scope :error, -> { where(status: 'error') }
  scope :prepared, -> { where.not(prepared_at: nil) }

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      created_at
      export_quantity
      export_updated_at
      id
      last_error
      prepared_at
      prices_cents
      product_id
      skip_reason
      status
      updated_at
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[product]
  end
end
