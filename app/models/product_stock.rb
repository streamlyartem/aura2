# frozen_string_literal: true

class ProductStock < ApplicationRecord
  self.implicit_order_column = :created_at

  belongs_to :product

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
end
