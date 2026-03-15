# frozen_string_literal: true

require 'base64'

module Insales
  module ApiV1
    module Cursor
      module_function

      def encode(sequence_id)
        Base64.urlsafe_encode64({ sequence_id: sequence_id.to_i }.to_json)
      end

      def decode(cursor)
        return 0 if cursor.blank?

        data = JSON.parse(Base64.urlsafe_decode64(cursor))
        Integer(data.fetch('sequence_id', 0))
      rescue StandardError
        raise ArgumentError, 'Invalid cursor'
      end
    end
  end
end
