# frozen_string_literal: true

require 'models/concerns/models_shared_examples'
require 'rails_helper'

RSpec.describe ProductStock do
  describe '#withdraw_stock' do
    let(:old_stock) { 100.0 }
    let(:stock_to_withdraw) { 20.0 }
    let(:new_stock) { 80.0 }
    let(:product_stock) { create(:product_stock, stock: old_stock) }

    it 'withdraws stock' do
      product_stock.withdraw_stock(stock_to_withdraw)
      product_stock.reload
      expect(product_stock.stock.to_f).to eq(new_stock)
    end
  end

  describe 'callbacks' do
    it 'buffers stock event and enqueues processor job after stock change' do
      ActiveJob::Base.queue_adapter = :test
      product = create(:product)

      expect do
        create(:product_stock, product: product, store_name: 'Тест', stock: 1)
      end.to have_enqueued_job(Insales::StockChangeEvents::ProcessJob)

      event = StockChangeEvent.find_by(product_id: product.id)
      expect(event).to be_present
      expect(event.status).to eq('pending')
    end
  end
end
