# frozen_string_literal: true

module Identity
  class AuthorizationStart
    attr_reader :authorization_request, :transaction

    def initialize(authorization_request:, transaction:)
      @authorization_request = authorization_request
      @transaction = transaction
      validate!
      freeze
    end

    def inspect
      "#<#{self.class.name} authorization_request=#{authorization_request.inspect} " \
        "transaction_id=#{transaction.id.inspect}>"
    end

    private

    def validate!
      raise ArgumentError, "authorization request is invalid" unless authorization_request.is_a?(AuthorizationRequest)
      raise ArgumentError, "OAuth transaction is invalid" unless transaction.is_a?(OauthTransaction) && transaction.persisted?
    end
  end
end
