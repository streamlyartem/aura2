class AddMediaTogglesToInsalesSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :insales_settings, :sync_images_enabled, :boolean, null: false, default: true
    add_column :insales_settings, :sync_videos_enabled, :boolean, null: false, default: false
  end
end
