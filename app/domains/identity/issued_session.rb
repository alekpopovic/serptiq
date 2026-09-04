# frozen_string_literal: true

module Identity
  class IssuedSession
    attr_reader :session, :token

    def initialize(session:, token:)
      @session = session
      @token = token
      freeze
    end

    def inspect
      "#<#{self.class.name} session_id=#{session.id.inspect} token=[FILTERED]>"
    end
    alias_method :to_s, :inspect
  end
end
