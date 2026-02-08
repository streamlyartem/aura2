# frozen_string_literal: true

namespace :moysklad do
  desc 'Import products from MoySklad'
  task import_products: :environment do
    MoyskladSync.new.import_products
    puts 'Done!'
  end
end
