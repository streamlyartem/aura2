# frozen_string_literal: true

class ExternalOrderEvent < ApplicationRecord
  self.table_name = 'external_order_events'

  belongs_to :external_order, optional: true

  validates :source, :source_event_id, :processing_status, presence: true
  validates :source_event_id, uniqueness: { scope: :source }
end
