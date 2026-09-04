# frozen_string_literal: true

module Identity
  class GoogleCallbackCompletion
    attr_reader :user, :return_to, :operation

    def initialize(user:, return_to:, operation:)
      @user = user
      @return_to = SafeReturnPath.call(return_to).freeze
      @operation = operation.to_s.freeze
      validate!
      freeze
    end

    def inspect
      "#<#{self.class.name} user_id=#{user.id.inspect} return_to=#{return_to.inspect} " \
        "operation=#{operation.inspect}>"
    end

    private

    def validate!
      raise ArgumentError, "callback user is invalid" unless user.is_a?(User) && user.persisted?
      raise ArgumentError, "callback operation is invalid" unless %w[sign_in link].include?(operation)
    end
  end
end
