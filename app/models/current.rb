# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :skip_insales_product_sync

  def skip_insales_product_sync?
    !!skip_insales_product_sync
  end
end
