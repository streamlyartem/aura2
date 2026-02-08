# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin Product Images Management' do
  let(:admin_user) { create(:admin_user) }

  before { login_as(admin_user, scope: :admin_user) }

  describe 'editing an existing product with images' do
    let(:add_image_title) { I18n.t('admin.products.form.add_image') }
    let(:update_button_title) { I18n.t('helpers.submit.update', model: Product.name) }
    let(:success_notice) { I18n.t('flash.actions.update.notice', resource_name: Product.name) }
    let(:image_path) { Rails.root.join('spec/support/images/files/borsch.png') }
    let(:product) { create(:product) }

    it 'allows admin to add images to existing product' do
      visit edit_admin_product_path(product)

      click_link(add_image_title)
      page.attach_file(image_path.to_s, make_visible: true)
      click_button(update_button_title)

      expect(page).to have_content(success_notice)

      product.reload
      expect(product.images.count).to eq(1)
      expect(product.images.first.file).to be_attached
    end

    context 'when product already has images' do
      before { create(:image, object: product) }

      it 'displays existing images in edit form' do
        visit edit_admin_product_path(product)

        expect(page).to have_css('img[src*="borsch"]')
      end

      it 'allows admin to remove images' do
        visit edit_admin_product_path(product)

        images_before = all('img[src*="borsch"]', visible: :all).count
        expect(images_before).to be > 0

        first('input[type="checkbox"][name*="_destroy"]', visible: :all).check

        click_button(update_button_title)

        expect(page).to have_content(success_notice)

        product.reload
        expect(product.images.count).to eq(images_before - 1)

        # Проверяем, что на странице стало на одну картинку меньше
        images_after = all('img[src*="borsch"]', visible: :all).count
        expect(images_after).to eq(images_before - 1)
      end

      it 'allows admin to add more images to existing product' do
        visit edit_admin_product_path(product)

        click_link(add_image_title)
        all('input[type="file"]', visible: :all).last.attach_file(image_path, make_visible: true)
        click_button(update_button_title)

        expect(page).to have_content(success_notice)

        product.reload
        expect(product.images.count).to eq(2)
      end
    end
  end
end
