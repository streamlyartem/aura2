# frozen_string_literal: true

class BackfillAdminUserAllowedPages < ActiveRecord::Migration[8.0]
  DEFAULT_ALLOWED_PATHS = [
    '/admin/dashboard',
    '/admin/products',
    '/admin/product_stocks',
    '/admin/moysklad_settings',
    '/admin/insales_settings',
    '/admin/insales_stock_sync',
    '/admin/insales_category_mappings',
    '/admin/insales_media_status',
    '/admin/insales_category_status',
    '/admin/price_types',
    '/admin/pricing_rulesets',
    '/admin/pricing_tiers',
    '/admin/admin_users',
    '/admin/user_actions'
  ].freeze

  def up
    execute <<~SQL.squish
      UPDATE admin_users
      SET allowed_admin_paths = '#{DEFAULT_ALLOWED_PATHS.to_json}'::jsonb,
          restrict_admin_pages = TRUE
      WHERE allowed_admin_paths IS NULL
         OR jsonb_typeof(allowed_admin_paths) <> 'array'
         OR jsonb_array_length(allowed_admin_paths) = 0
    SQL
  end

  def down
    # no-op: keep explicit page visibility configuration for admins
  end
end
