# frozen_string_literal: true

ActiveAdmin.register_page 'Order Write Offs' do
  menu parent: 'Заказы', label: 'Списания', priority: 53,
       if: proc { current_admin_user&.can_access_admin_path?('/admin/order_write_offs') }

  content title: 'Списания по заказам' do
    para 'Раздел в разработке.'
  end
end
