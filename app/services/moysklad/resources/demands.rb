# frozen_string_literal: true

module Moysklad
  module Resources
    # Demands resource for Moysklad API
    class Demands < Base
      def entity_path
        'entity/demand'
      end

      def create(organization_meta:, agent_meta:, store_meta:, positions:, description: 'Списание из Aura')
        payload = {
          organization: { meta: organization_meta },
          agent: { meta: agent_meta },
          store: { meta: store_meta },
          description: description,
          positions: positions
        }

        http_client.post(entity_path, payload)
      end
    end
  end
end
