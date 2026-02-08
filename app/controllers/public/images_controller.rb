# frozen_string_literal: true

module Public
  class ImagesController < ApplicationController
    skip_before_action :verify_authenticity_token

    def show
      image = Image.find_by(id: params[:image_id])
      return head :not_found unless image&.file&.attached?

      blob = image.file.blob

      response.headers['Cache-Control'] = 'public, max-age=3600'
      send_data(
        image.file.download,
        type: blob.content_type,
        disposition: "inline; filename=\"#{blob.filename}\""
      )
    rescue ActiveStorage::FileNotFoundError, Aws::S3::Errors::NoSuchKey
      head :not_found
    end
  end
end
