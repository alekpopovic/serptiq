# frozen_string_literal: true

module Identity
  class VerifyRecentSession
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(session:, user_id:)
      raise RecentAuthenticationRequired unless session

      current = Session.lock.includes(:user).find(session.id)
      now = @clock.call
      valid = current.user_id.to_s == user_id.to_s && current.active_at?(now) &&
        current.authenticated_at >= now - SessionPolicy::RECENT_AUTHENTICATION_WINDOW
      raise RecentAuthenticationRequired unless valid

      current
    rescue ActiveRecord::RecordNotFound
      raise RecentAuthenticationRequired, cause: nil
    end
  end
end
