# frozen_string_literal: true

module Insales
  module ApiV1
    class ErrorResponse < StandardError
      attr_reader :code, :message, :status, :details, :retryable

      def initialize(code:, message:, status:, details: nil, retryable: false)
        super(message)
        @code = code
        @message = message
        @status = status
        @details = details
        @retryable = retryable
      end
    end
  end
end
