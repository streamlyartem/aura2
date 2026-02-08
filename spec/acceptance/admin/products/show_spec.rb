# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin Product Images Management' do
  let(:admin_user) { create(:admin_user) }

  before { login_as(admin_user, scope: :admin_user) }

  describe 'viewing product with images' do
    let(:product) { create(:product) }

    before { create_list(:image, 2, object: product) }

    it 'displays all product images on show page' do
      visit admin_product_path(product)

      expect(page).to have_content(product.name)
      expect(page).to have_content(product.sku)

      images = all('img[src*="borsch"]')
      expect(images.count).to eq(2)
    end
  end

  describe 'product without images' do
    let!(:product) { create(:product) }

    it 'shows "no images" status on show page' do
      visit admin_product_path(product)

      expect(page).to have_content(I18n.t('admin.products.show.no_images'))
    end
  end
end
