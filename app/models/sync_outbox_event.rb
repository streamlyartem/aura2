# frozen_string_literal: true

class SyncOutboxEvent < ApplicationRecord
  self.primary_key = :id

  EVENT_TYPES = %w[
    product.created
    product.updated
    product.deleted
    stock.updated
    media.updated
  ].freeze

  validates :aggregate_type, :aggregate_id, :event_type, :occurred_at, presence: true
  validates :event_type, inclusion: { in: EVENT_TYPES }

  scope :after_cursor, ->(cursor) { where('id > ?', cursor.to_i) }
  scope :ordered, -> { order(:id) }
end
