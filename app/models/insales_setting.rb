# frozen_string_literal: true

class InsalesSetting < ApplicationRecord
  self.implicit_order_column = :created_at
  self.filter_attributes |= [:password]

  validates :login, :password, :base_url, :category_id, presence: true
  validates :image_url_mode, inclusion: { in: %w[service_url rails_url] }
  validate :single_record

  def self.ransackable_attributes(_auth_object = nil)
    %w[allowed_store_names base_url cached_store_names cached_store_names_synced_at category_id created_at default_collection_id id image_url_mode login updated_at]
  end

  def allowed_store_names_list
    Array(allowed_store_names).map(&:to_s).map(&:strip).reject(&:blank?).uniq
  end

  def cached_store_names_list
    Array(cached_store_names).map(&:to_s).map(&:strip).reject(&:blank?).uniq
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  private

  def single_record
    return unless InsalesSetting.where.not(id: id).exists?

    errors.add(:base, 'Only one InsalesSetting record is allowed')
  end
end
