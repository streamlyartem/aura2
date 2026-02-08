# frozen_string_literal: true

Rails.application.configure do
  config.active_storage.routes_prefix = '/storage'
  config.active_storage.service_urls_expire_in = 9.hours
end

Rails.application.default_url_options[:host] = ENV.fetch('API_HOST', 'localhost:3000')
