# frozen_string_literal: true

namespace :moysklad do
  desc 'Import products from MoySklad'
  task import_products: :environment do
    MoyskladSync.new.import_products
    puts 'Done!'
  end

  namespace :webhooks do
    desc 'Ensure MoySklad webhooks exist'
    task ensure: :environment do
      result = Moysklad::Webhooks::Registrar.new.ensure!
      puts result.inspect
    end
  end
end
