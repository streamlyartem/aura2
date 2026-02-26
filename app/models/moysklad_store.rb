# frozen_string_literal: true

class MoyskladStore < ApplicationRecord
  scope :selected, -> { where(selected_for_import: true) }

  validates :name, presence: true, uniqueness: true

  def self.refresh_from_moysklad!(client: MoyskladClient.new)
    names = Array(client.store_names).map(&:to_s).map(&:strip).reject(&:blank?).uniq.sort
    now = Time.current

    names.each do |name|
      record = find_or_initialize_by(name: name)
      record.last_seen_at = now
      record.save!
    end

    names
  end

  def self.selected_names
    selected.order(:name).pluck(:name)
  end

  def self.all_names
    order(:name).pluck(:name)
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at id last_seen_at name selected_for_import updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
