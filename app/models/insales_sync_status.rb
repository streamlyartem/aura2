# frozen_string_literal: true

class InsalesSyncStatus < ApplicationRecord
  self.implicit_order_column = :created_at

  validates :store_name, presence: true, uniqueness: true
end
