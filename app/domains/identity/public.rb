# frozen_string_literal: true

module Identity
  module Public
    module_function

    def issue_session(user:, metadata: SessionMetadata.empty, clock: -> { Time.current })
      SessionLifecycle.new(clock: clock).issue(user: user, metadata: metadata)
    end

    def authenticate_session!(token:, metadata: SessionMetadata.empty, clock: -> { Time.current })
      SessionLifecycle.new(clock: clock).authenticate!(token: token, metadata: metadata)
    end

    def rotate_session!(session:, metadata: SessionMetadata.empty, reason: "rotated", clock: -> { Time.current })
      SessionLifecycle.new(clock: clock).rotate!(session: session, metadata: metadata, reason: reason)
    end

    def revoke_session(session:, reason: "logout", clock: -> { Time.current })
      SessionLifecycle.new(clock: clock).revoke(session: session, reason: reason)
    end
  end
end
