# frozen_string_literal: true

ActiveSupport.on_load(:active_admin_controller) do
  before_action :authorize_page_visibility

  private

  def authorize_page_visibility
    user = current_admin_user
    return unless user

    path = "/#{controller_path}".sub(%r{/+}, '/')
    return if user.can_access_admin_path?(path)

    redirect_to user.first_allowed_admin_path, alert: 'У вас нет доступа к этому разделу.'
  end
end

