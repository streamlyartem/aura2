# frozen_string_literal: true

class InsalesSyncRun < ApplicationRecord
  self.implicit_order_column = :created_at

  validates :store_name, presence: true
  validates :status, presence: true
end
