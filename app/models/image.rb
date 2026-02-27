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
  belongs_to :uploaded_by_admin_user, class_name: 'AdminUser', optional: true, inverse_of: :uploaded_images

  before_validation :assign_uploaded_by_admin_user, on: :create
  after_commit :enqueue_insales_sync_trigger, on: %i[create destroy]

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

  private

  def assign_uploaded_by_admin_user
    self.uploaded_by_admin_user_id ||= Current.admin_user&.id
  end

  def enqueue_insales_sync_trigger
    return unless object_type == 'Product'
    return if object_id.blank?

    Insales::SyncProductTriggerJob.perform_later(product_id: object_id, reason: 'media_changed')
  end
end
