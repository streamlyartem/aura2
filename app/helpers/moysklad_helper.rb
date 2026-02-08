# frozen_string_literal: true

module MoyskladHelper
  def extract_uuid(href)
    return if href.blank?

    href.split('/').last.split('?').first
  end
end
