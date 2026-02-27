# frozen_string_literal: true

class AdminUser < ApplicationRecord
  ADMIN_PAGE_OPTIONS = {
    'Dashboard' => '/admin/dashboard',
    'Все товары из МС' => '/admin/products',
    'Остатки из МС' => '/admin/product_stocks',
    'Настройки МС' => '/admin/moysklad_settings',
    'Настройки InSales' => '/admin/insales_settings',
    'InSales Stock Sync' => '/admin/insales_stock_sync',
    'Каталог InSales' => '/admin/insales_catalog_items',
    'InSales Orders' => '/admin/insales_orders',
    'InSales Sync' => '/admin/insales_sync',
    'InSales Category Mappings' => '/admin/insales_category_mappings',
    'InSales Media' => '/admin/insales_media',
    'InSales Media Status' => '/admin/insales_media_status',
    'InSales Category Status' => '/admin/insales_category_status',
    'Склады МС' => '/admin/moysklad_stores',
    'Admin Users' => '/admin/admin_users',
    'User Actions' => '/admin/user_actions'
  }.freeze

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  validates :email, presence: true
  validates :reset_password_token, uniqueness: true, allow_nil: true
  validates :allowed_admin_paths, presence: true

  has_many :uploaded_images, class_name: 'Image', foreign_key: :uploaded_by_admin_user_id, inverse_of: :uploaded_by_admin_user, dependent: :nullify

  before_validation :normalize_allowed_admin_paths
  before_validation :enable_page_restrictions

  def self.ransackable_attributes(_auth_object = nil)
    %w[id email created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  def can_access_admin_path?(path)
    normalized = normalize_admin_path(path)
    return true if normalized.blank?

    allowed_admin_paths.include?(normalized)
  end

  def first_allowed_admin_path
    allowed_admin_paths.first.presence || '/admin/dashboard'
  end

  private

  def normalize_allowed_admin_paths
    self.allowed_admin_paths = Array(allowed_admin_paths).filter_map do |path|
      normalized = normalize_admin_path(path)
      normalized if normalized.present?
    end.uniq
  end

  def normalize_admin_path(path)
    value = path.to_s.strip
    return nil if value.blank?

    value = "/#{value}" unless value.start_with?('/')
    value = value.sub(/\/+$/, '')
    value == '' ? '/' : value
  end

  def enable_page_restrictions
    self.restrict_admin_pages = true
  end
end
