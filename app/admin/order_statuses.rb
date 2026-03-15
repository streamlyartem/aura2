# frozen_string_literal: true

ActiveAdmin.register_page 'Order Statuses' do
  menu parent: 'Заказы', label: 'Статусы', priority: 52,
       if: proc { current_admin_user&.can_access_admin_path?('/admin/order_statuses') }

  content title: 'Статусы заказов' do
    para 'Раздел в разработке.'
  end
end
