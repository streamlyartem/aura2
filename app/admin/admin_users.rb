# frozen_string_literal: true

ActiveAdmin.register AdminUser do
  menu parent: 'Users', label: 'Admin Users',
       if: proc { current_admin_user&.can_access_admin_path?('/admin/admin_users') }

  permit_params :email, :password, :password_confirmation, :restrict_admin_pages, allowed_admin_paths: []

  index do
    selectable_column
    id_column
    column :email
    column :restrict_admin_pages
    column :current_sign_in_at
    column :sign_in_count
    column :created_at
    actions
  end

  filter :email
  filter :restrict_admin_pages
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
      f.input :restrict_admin_pages, label: 'Ограничить видимость разделов'
      f.input :allowed_admin_paths,
              as: :check_boxes,
              collection: AdminUser::ADMIN_PAGE_OPTIONS.map { |label, path| [label, path] },
              label: 'Доступные страницы'
    end

    f.actions
  end
end
