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
      result = Moysklad::WebhooksManager.new.ensure
      puts result.inspect
    end

    desc 'List MoySklad webhooks'
    task list: :environment do
      rows = Moysklad::WebhooksManager.new.list
      puts rows.inspect
    end

    desc 'Delete MoySklad webhooks for staging URL'
    task delete: :environment do
      result = Moysklad::WebhooksManager.new.delete_all_for_url
      puts result.inspect
    end
  end
end
