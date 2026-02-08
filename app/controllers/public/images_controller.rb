# frozen_string_literal: true

module Public
  class ImagesController < ApplicationController
    skip_before_action :verify_authenticity_token

    def show
      image = Image.find_by(id: params[:image_id])
      return head :not_found unless image&.file&.attached?

      blob = image.file.blob
      data = image.file.download

      response.headers['Cache-Control'] = 'public, max-age=3600'
      send_data(
        data,
        type: blob.content_type,
        disposition: "inline; filename=\"#{blob.filename}\""
      )
    end
  end
end
