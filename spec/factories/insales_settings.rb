# frozen_string_literal: true

FactoryBot.define do
  factory :insales_setting do
    base_url { 'https://example.myinsales.ru' }
    login { 'demo' }
    password { 'secret' }
    category_id { '123' }
    image_url_mode { 'service_url' }
    allowed_store_names { [MoyskladClient::TEST_STORE_NAME] }
    skip_products_without_sku { false }
    skip_products_with_nonpositive_stock { false }
  end
end
