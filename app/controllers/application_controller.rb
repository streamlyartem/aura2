# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  around_action :set_current_admin_user

  private

  def set_current_admin_user
    Current.admin_user = current_admin_user if respond_to?(:current_admin_user)
    yield
  ensure
    Current.reset
  end
end
