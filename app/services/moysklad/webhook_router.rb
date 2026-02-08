# frozen_string_literal: true

module Moysklad
  # Routes webhook payloads to specific handlers based on entity type and action.
  #
  # To add a new webhook handler:
  # 1. Create a new handler class in app/services/moysklad/webhook_handlers/
  #    inheriting from WebhookHandlers::BaseHandler
  # 2. Register it in the handler_for method below
  #
  # Example:
  #   def self.handler_for(entity_type, action)
  #     case [entity_type, action]
  #     when %w[product CREATE] then WebhookHandlers::ProductCreateHandler
  #     when %w[product UPDATE] then WebhookHandlers::ProductUpdateHandler
  #     when %w[product DELETE] then WebhookHandlers::ProductDeleteHandler
  #     when %w[demand CREATE] then WebhookHandlers::DemandCreateHandler  # New handler
  #     end
  #   end
  class WebhookRouter
    def initialize(event)
      @event = event
    end

    def handle
      entity_type = @event.dig('meta', 'type')
      action = @event['action']

      handler_class = self.class.handler_for(entity_type, action)

      if handler_class
        handler_class.new(@event).handle
      else
        Rails.logger.info "[Moysklad Webhook] Unhandled event: #{entity_type} #{action}"
      end
    end

    # Registry mapping [entity_type, action] to handler classes
    # Uses a method instead of a constant to support Rails autoloading
    def self.handler_for(entity_type, action)
      case [entity_type, action]
      when %w[product CREATE] then WebhookHandlers::ProductCreateHandler
      when %w[product UPDATE] then WebhookHandlers::ProductUpdateHandler
      when %w[product DELETE] then WebhookHandlers::ProductDeleteHandler
      end
    end
  end
end
