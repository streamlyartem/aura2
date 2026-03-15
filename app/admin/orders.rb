# frozen_string_literal: true

ActiveAdmin.register_page 'Orders' do
  menu parent: 'Заказы', label: 'Заказы', priority: 50,
       if: proc { current_admin_user&.can_access_admin_path?('/admin/orders') }

  content title: 'Заказы' do
    para 'Раздел для заказов со всех витрин.'
  end
end
