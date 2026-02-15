# frozen_string_literal: true

class InsalesMediaMapping < ApplicationRecord
  belongs_to :media_item, class_name: 'InsalesMediaItem', foreign_key: :aura_media_item_id

  validates :aura_media_item_id, :insales_product_id, :kind, presence: true
  validates :kind, inclusion: { in: InsalesMediaItem::KINDS }
end
