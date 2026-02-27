# frozen_string_literal: true

require "rails_helper"

RSpec.describe Insales::StockChangeEvents::Buffer do
  let!(:setting) { create(:insales_setting, allowed_store_names: ["Тест"]) }
  let!(:product) { create(:product) }

  describe ".call" do
    it "deduplicates by product_id under repeated events" do
      first_time = 2.minutes.ago
      second_time = Time.current

      described_class.call(
        product_id: product.id,
        store_name: "Склад A",
        new_stock: 10,
        event_updated_at: first_time
      )
      described_class.call(
        product_id: product.id,
        store_name: "Склад A",
        new_stock: 11,
        event_updated_at: second_time
      )

      expect(StockChangeEvent.where(product_id: product.id).count).to eq(1)
      event = StockChangeEvent.find_by!(product_id: product.id)
      expect(event.event_updated_at.to_i).to eq(second_time.to_i)
    end

    it "promotes normal priority to high and never downgrades high" do
      described_class.call(
        product_id: product.id,
        store_name: "Склад A",
        new_stock: 12,
        event_updated_at: 3.minutes.ago
      )
      expect(StockChangeEvent.find_by!(product_id: product.id).priority).to eq("normal")

      described_class.call(
        product_id: product.id,
        store_name: "Склад A",
        new_stock: 0,
        event_updated_at: 2.minutes.ago
      )
      expect(StockChangeEvent.find_by!(product_id: product.id).priority).to eq("high")

      described_class.call(
        product_id: product.id,
        store_name: "Склад A",
        new_stock: 15,
        event_updated_at: Time.current
      )
      expect(StockChangeEvent.find_by!(product_id: product.id).priority).to eq("high")
    end

    it "sets high priority for selling stores" do
      described_class.call(
        product_id: product.id,
        store_name: "Тест",
        new_stock: 5,
        event_updated_at: Time.current
      )

      event = StockChangeEvent.find_by!(product_id: product.id)
      expect(event.priority).to eq("high")
      expect(event.reason).to eq("selling_store")
    end

    it "keeps one row for 1000 repeated webhook updates of the same product" do
      1000.times do |idx|
        described_class.call(
          product_id: product.id,
          store_name: "Склад A",
          new_stock: 50 + idx,
          event_updated_at: Time.current + idx.seconds
        )
      end

      expect(StockChangeEvent.where(product_id: product.id).count).to eq(1)
    end
  end
end
