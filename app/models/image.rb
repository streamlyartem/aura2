# frozen_string_literal: true

class Image < ApplicationRecord
  self.implicit_order_column = :created_at

  ALLOWED_MIME_TYPES = %w[
    image/gif
    image/jpeg
    image/png
    image/svg+xml
    image/tiff
    image/x-cmx
    image/x-rgb
    image/heic
    image/heif
    video/mp4
    video/mpeg
    video/quicktime
    video/x-msvideo
    video/x-ms-wmv
    video/webm
    video/ogg
  ].freeze

  belongs_to :object, polymorphic: true, optional: true

  has_one_attached :file

  validates :file, presence: true, content_type: ALLOWED_MIME_TYPES, size: { less_than: 35.megabytes }

  delegate :url, to: :file, prefix: :service

  def url
    return nil unless persisted? && file.attached?

    Rails.application.routes.url_helpers.rails_blob_url(file)
  end

  def video?
    return false unless file.attached?

    file.content_type&.start_with?('video/')
  end

  def image?
    return false unless file.attached?

    file.content_type&.start_with?('image/')
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at id object_id object_type updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
