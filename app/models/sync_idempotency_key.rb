# frozen_string_literal: true

class SyncIdempotencyKey < ApplicationRecord
  validates :idempotency_key, presence: true, uniqueness: true
  validates :request_hash, presence: true

  scope :active, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }
end
