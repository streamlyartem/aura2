# frozen_string_literal: true

ActiveAdmin.register ProductStock do
  menu label: 'Остатки из МС', parent: 'МойСклад', priority: 4,
       if: proc { current_admin_user&.can_access_admin_path?('/admin/product_stocks') }

  actions :index, :show
  config.batch_actions = false
  config.filters = false

  controller do
    def scoped_collection
      scope = super.includes(:product)
      settings = InsalesSetting.first
      allowed = settings&.allowed_store_names_list
      allowed = [MoyskladClient::TEST_STORE_NAME] if allowed.blank?
      scope.where(store_name: allowed)
    end
  end

  member_action :write_off, method: %i[get post] do
    @product_stock = ProductStock.find(params[:id])

    if request.post?
      stock = params.dig(:product_stock, :stock).to_f

      if stock <= 0 || stock > @product_stock.stock.to_f
        redirect_to resource_path(@product_stock), alert: I18n.t('admin.product_stocks.errors.invalid_quantity')
        return
      end

      client = MoyskladClient.new
      response = client.create_demand(@product_stock.product, stock)

      if [200, 201].include?(response&.status)
        @product_stock.withdraw_stock(stock)
        redirect_to resource_path(@product_stock), notice: I18n.t('admin.product_stocks.notices.demand_created')
      else
        redirect_to resource_path(@product_stock),
                    alert: I18n.t('admin.product_stocks.notices.demand_failed', status: response&.status)
      end
    end
  end

  action_item :write_off, only: :show do
    link_to 'Списать', write_off_admin_product_stock_path(resource), method: :get
  end

  index do
    selectable_column
    id_column
    column :product do |stock|
      link_to stock.product.name, admin_product_path(stock.product) if stock.product
    end
    column :store_name
    column :stock
    column :free_stock
    column :reserve
    column :synced_at
    column :created_at
    column :updated_at
    actions
  end

  show do
    attributes_table_for(resource) do
      row :id
      row :product
      row :store_name
      row :stock
      row :free_stock
      row :reserve
      row :synced_at
      row :created_at
      row :updated_at
    end
  end
end
