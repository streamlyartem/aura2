# frozen_string_literal: true

ActiveAdmin.register_page 'InSales Orders' do
  menu parent: 'InSales', label: 'Заказы InSales', priority: 2,
       if: proc { current_admin_user&.can_access_admin_path?('/admin/insales_orders') }

  content title: 'Заказы InSales' do
    para 'Раздел в разработке'
  end
end
