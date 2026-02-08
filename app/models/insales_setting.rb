# frozen_string_literal: true

class InsalesSetting < ApplicationRecord
  self.implicit_order_column = :created_at
  self.filter_attributes |= [:password]

  validates :login, :password, :base_url, :category_id, presence: true
  validates :image_url_mode, inclusion: { in: %w[service_url rails_url] }
  validate :single_record

  private

  def single_record
    return unless InsalesSetting.where.not(id: id).exists?

    errors.add(:base, 'Only one InsalesSetting record is allowed')
  end
end
