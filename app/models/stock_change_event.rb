# frozen_string_literal: true

class StockChangeEvent < ApplicationRecord
  PRIORITIES = %w[high normal].freeze
  STATUSES = %w[pending processing failed].freeze

  belongs_to :product

  validates :priority, presence: true, inclusion: { in: PRIORITIES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :reason, presence: true
  validates :event_updated_at, presence: true

  scope :pending, -> { where(status: "pending") }
  scope :processing, -> { where(status: "processing") }
  scope :retry_ready, ->(now = Time.current) { where("next_retry_at IS NULL OR next_retry_at <= ?", now) }
  scope :priority_order, -> { order(Arel.sql("CASE priority WHEN 'high' THEN 0 ELSE 1 END"), :event_updated_at, :created_at) }
  scope :for_priority, ->(priority) { where(priority: priority) }
  scope :stale_processing, ->(cutoff) { processing.where("locked_at IS NOT NULL AND locked_at < ?", cutoff) }
end
