# frozen_string_literal: true

require 'set'

ActiveAdmin.register_page 'User Actions' do
  menu parent: 'Users', label: 'User Actions',
       if: proc { current_admin_user&.can_access_admin_path?('/admin/user_actions') }

  content title: 'User Actions' do
    users = AdminUser.order(:email).to_a
    photos_by_user = Image.where.not(uploaded_by_admin_user_id: nil).group(:uploaded_by_admin_user_id).count

    product_ids_by_user = Hash.new { |h, k| h[k] = Set.new }
    Image.where.not(uploaded_by_admin_user_id: nil).where(object_type: 'Product').pluck(:uploaded_by_admin_user_id, :object_id).each do |user_id, product_id|
      product_ids_by_user[user_id] << product_id
    end

    error_counts_by_user = {}
    last_error_by_user = {}

    product_ids_by_user.each do |user_id, product_ids|
      scope = InsalesMediaSyncState.where(product_id: product_ids.to_a).where(status: 'error')
      error_counts_by_user[user_id] = scope.count
      last_error_by_user[user_id] = scope.order(updated_at: :desc).limit(1).pick(:last_error)
    end

    panel 'Действия по пользователю' do
      table_for users do
        column('Пользователь') { |u| u.email }
        column('Фото загружено') { |u| photos_by_user[u.id] || 0 }
        column('Ошибки синка') { |u| error_counts_by_user[u.id] || 0 }
        column('Последняя ошибка') { |u| last_error_by_user[u.id].presence || '—' }
      end
    end
  end
end
