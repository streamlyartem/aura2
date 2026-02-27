# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :admin_user
  attribute :skip_insales_product_sync
  attribute :skip_stock_change_processor_enqueue

  def skip_insales_product_sync?
    !!skip_insales_product_sync
  end

  def skip_stock_change_processor_enqueue?
    !!skip_stock_change_processor_enqueue
  end
end
