# frozen_string_literal: true

require "rails_helper"

RSpec.describe Insales::StockChangeEvents::Processor do
  let!(:setting) { create(:insales_setting, allowed_store_names: ["Тест"]) }
  let!(:product) { create(:product, unit_type: "weight", weight: 100, retail_price: 100, sku: "SKU-1") }
  let(:sync_service) { instance_double(Insales::SyncProductTrigger) }
  let(:processor) { described_class.new(worker_id: "spec-worker", sync_service: sync_service) }

  before do
    create(:product_stock, product: product, store_name: "Тест", stock: 10)
    StockChangeEvent.delete_all
    allow(sync_service).to receive(:call).and_return(
      Insales::SyncProductTrigger::Result.new(status: "success", action: "publish", message: "ok")
    )
  end

  describe "#process" do
    it "processes high priority events before normal priority events" do
      high = create(:stock_change_event, product: product, priority: "high", event_updated_at: 2.minutes.ago)
      other_product = create(:product, unit_type: "weight", weight: 100, retail_price: 100, sku: "SKU-2")
      create(:product_stock, product: other_product, store_name: "Склад A", stock: 10)
      StockChangeEvent.where(product_id: other_product.id).delete_all
      normal = create(:stock_change_event, product: other_product, priority: "normal", event_updated_at: 1.minute.ago)

      order = []
      allow(sync_service).to receive(:call) do |product_id:, reason:|
        order << product_id
        Insales::SyncProductTrigger::Result.new(status: "success", action: "publish", message: reason)
      end

      processor.process(batch_size: 10, max_batches: 1)

      expect(order).to eq([high.product_id, normal.product_id])
    end

    it "skips stale claimed event when a newer version exists and processes only latest payload" do
      event = create(:stock_change_event, product: product, priority: "high", event_updated_at: 5.minutes.ago)
      claimed_version = event.event_updated_at

      event.update!(event_updated_at: Time.current, status: "pending")

      expect(sync_service).not_to receive(:call)

      processor.send(:process_event, event.tap { |e| e.event_updated_at = claimed_version })

      expect(event.reload.status).to eq("pending")
    end

    it "implements last-write-wins for racing events A and B" do
      create(:stock_change_event, product: product, priority: "high", event_updated_at: 5.minutes.ago)
      old_claim = StockChangeEvent.find_by!(product_id: product.id)

      latest_time = Time.current
      Insales::StockChangeEvents::Buffer.call(
        product_id: product.id,
        store_name: "Тест",
        new_stock: 8,
        event_updated_at: latest_time
      )

      processor.send(:process_event, old_claim)
      processor.process(batch_size: 10, max_batches: 1)

      expect(sync_service).to have_received(:call).once
      item = InsalesCatalogItem.find_by!(product_id: product.id)
      expect(item.export_updated_at.to_i).to eq(latest_time.to_i)
      expect(StockChangeEvent.find_by(product_id: product.id)).to be_nil
    end

    it "requeues stale processing events after lock TTL" do
      event = create(
        :stock_change_event,
        product: product,
        status: "processing",
        locked_at: 10.minutes.ago,
        locked_by: "old-worker"
      )

      processor.send(:release_stale_processing!)

      event.reload
      expect(event.status).to eq("pending")
      expect(event.locked_at).to be_nil
      expect(event.locked_by).to be_nil
    end

    it "retries retryable 429 errors and keeps event" do
      event = create(:stock_change_event, product: product, priority: "high")
      allow(sync_service).to receive(:call).and_return(
        Insales::SyncProductTrigger::Result.new(status: "error", action: "publish", message: "HTTP 429")
      )

      processor.process(batch_size: 10, max_batches: 1)

      event.reload
      expect(event.status).to eq("pending")
      expect(event.attempts).to eq(1)
      expect(event.next_retry_at).to be_present
    end

    it "marks non-retryable 404 errors as failed" do
      event = create(:stock_change_event, product: product, priority: "high")
      allow(sync_service).to receive(:call).and_return(
        Insales::SyncProductTrigger::Result.new(status: "error", action: "publish", message: "HTTP 404")
      )

      processor.process(batch_size: 10, max_batches: 1)

      event.reload
      expect(event.status).to eq("failed")
      expect(event.last_error).to include("HTTP 404")
    end

    it "stores export_updated_at in InsalesCatalogItem before sync" do
      event_time = Time.current.change(usec: 0)
      create(:stock_change_event, product: product, priority: "high", event_updated_at: event_time)

      processor.process(batch_size: 10, max_batches: 1)

      item = InsalesCatalogItem.find_by!(product_id: product.id)
      expect(item.export_updated_at.to_i).to eq(event_time.to_i)
      expect(sync_service).to have_received(:call).with(product_id: product.id, reason: "stock_changed")
    end
  end
end
