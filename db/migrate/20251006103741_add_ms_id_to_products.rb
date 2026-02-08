class AddMsIdToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :ms_id, :uuid
  end
end
