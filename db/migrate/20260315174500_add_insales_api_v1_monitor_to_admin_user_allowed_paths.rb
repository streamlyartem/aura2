# frozen_string_literal: true

class AddInsalesApiV1MonitorToAdminUserAllowedPaths < ActiveRecord::Migration[8.0]
  TARGET_PATH = '/admin/insales_api_v1_monitor'

  def up
    execute <<~SQL.squish
      UPDATE admin_users
      SET allowed_admin_paths = allowed_admin_paths || to_jsonb(ARRAY['#{TARGET_PATH}'])
      WHERE jsonb_typeof(allowed_admin_paths) = 'array'
        AND NOT (allowed_admin_paths @> to_jsonb(ARRAY['#{TARGET_PATH}']))
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE admin_users
      SET allowed_admin_paths = (
        SELECT COALESCE(jsonb_agg(value), '[]'::jsonb)
        FROM jsonb_array_elements_text(allowed_admin_paths) AS value
        WHERE value <> '#{TARGET_PATH}'
      )
      WHERE jsonb_typeof(allowed_admin_paths) = 'array'
    SQL
  end
end
