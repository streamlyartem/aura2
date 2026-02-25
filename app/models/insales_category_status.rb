# frozen_string_literal: true

class InsalesCategoryStatus < ApplicationRecord
  validates :aura_path, presence: true, uniqueness: true
  validates :sync_status, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[aura_path insales_collection_id insales_collection_title insales_parent_collection_id sync_status last_error synced_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
