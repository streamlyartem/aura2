# frozen_string_literal: true

ActiveAdmin.register AdminUser do
  menu parent: 'Users', label: 'Admin Users',
       if: proc { current_admin_user&.can_access_admin_path?('/admin/admin_users') }

  permit_params :email, :password, :password_confirmation, allowed_admin_paths: []

  index do
    selectable_column
    id_column
    column :email
    column :current_sign_in_at
    column :sign_in_count
    column :created_at
    actions
  end

  filter :email
  filter :current_sign_in_at
  filter :sign_in_count
  filter :created_at

  form do |f|
    f.inputs 'Основное' do
      f.input :email
      f.input :password
      f.input :password_confirmation
    end

    f.inputs 'Видимость разделов' do
      selected_paths = f.object.allowed_admin_paths.presence || AdminUser::ADMIN_PAGE_OPTIONS.values
      f.input :allowed_admin_paths,
              as: :check_boxes,
              collection: AdminUser::ADMIN_PAGE_OPTIONS.map { |label, path| [label, path] },
              selected: selected_paths,
              label: 'Доступные страницы'
    end

    f.actions
  end
end
