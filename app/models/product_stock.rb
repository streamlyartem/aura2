# frozen_string_literal: true

class ProductStock < ApplicationRecord
  self.implicit_order_column = :created_at

  belongs_to :product
  after_commit :buffer_insales_stock_change, on: %i[create update destroy]
  after_commit :publish_outbox_stock_update, on: %i[create update destroy]

  validates :store_name, presence: true

  scope :recent, -> { order(synced_at: :desc) }

  def self.ransackable_attributes(_auth_object = nil)
    %w[id store_name stock free_stock reserve synced_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[product]
  end

  def withdraw_stock(stock_to_withdraw)
    new_stock = stock - stock_to_withdraw
    update(stock: new_stock)
    save!
  end

  private

  def buffer_insales_stock_change
    return if product_id.blank?

    Insales::StockChangeEvents::Buffer.call(
      product_id: product_id,
      store_name: store_name,
      new_stock: destroyed? ? 0 : stock.to_f,
      event_updated_at: updated_at || Time.current
    )
    return if Current.skip_stock_change_processor_enqueue?

    Insales::StockChangeEvents::ProcessJob.perform_later
  end

  def publish_outbox_stock_update
    return if product_id.blank?
    return unless Insales::ApiV1::FeatureFlags.outbox_enabled?

    product = Product.find_by(id: product_id)
    return unless product

    payload = Insales::ApiV1::ProductDtoSerializer.new(product).as_json
    Insales::ApiV1::OutboxPublisher.publish!(
      aggregate_type: 'Product',
      aggregate_id: product.id,
      event_type: 'stock.updated',
      payload: payload,
      occurred_at: updated_at || Time.current
    )
  rescue StandardError => e
    Rails.logger.warn("[APIv1][Outbox] stock_update product=#{product_id} failed: #{e.class} #{e.message}")
  end
end
