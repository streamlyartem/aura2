# frozen_string_literal: true

class AddAdminVisibilityAndImageUploader < ActiveRecord::Migration[8.0]
  def change
    add_column :admin_users, :restrict_admin_pages, :boolean, null: false, default: false
    add_column :admin_users, :allowed_admin_paths, :jsonb, null: false, default: []

    add_reference :images, :uploaded_by_admin_user, type: :bigint, null: true, foreign_key: { to_table: :admin_users }
  end
end

