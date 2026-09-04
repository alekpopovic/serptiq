# frozen_string_literal: true

module Identity
  module CurrentRequest
    extend ActiveSupport::Concern

    included do
      around_action :with_current_identity
    end

    private

    def with_current_identity
      Current.reset
      load_current_identity
      yield
    ensure
      Current.reset
    end

    def load_current_identity
      token = identity_session_cookie.read
      return if token.blank?

      current_session = Public.authenticate_session!(
        token: token,
        metadata: SessionMetadata.from_request(request)
      )
      Current.session = current_session
      Current.user = current_session.user
    rescue Error
      identity_session_cookie.delete
    end

    def establish_identity_session!(user)
      issued = if Current.session&.user_id == user.id
        Public.rotate_session!(
          session: Current.session,
          metadata: SessionMetadata.from_request(request)
        )
      else
        Public.revoke_session(session: Current.session, reason: "rotated") if Current.session
        Public.issue_session(
          user: user,
          metadata: SessionMetadata.from_request(request)
        )
      end
      identity_session_cookie.write(token: issued.token, expires_at: issued.session.expires_at)
      Current.session = issued.session
      Current.user = issued.session.user
      issued.session
    end

    def rotate_current_session!(reason: "privilege_changed")
      raise AuthenticationRequired unless Current.session

      issued = Public.rotate_session!(
        session: Current.session,
        metadata: SessionMetadata.from_request(request),
        reason: reason
      )
      identity_session_cookie.write(token: issued.token, expires_at: issued.session.expires_at)
      Current.session = issued.session
      issued.session
    end

    def accept_issued_identity_session!(issued)
      identity_session_cookie.write(token: issued.token, expires_at: issued.session.expires_at)
      Current.session = issued.session
      Current.user = issued.session.user
      issued.session
    end

    def identity_session_cookie
      @identity_session_cookie ||= SessionCookie.new(cookies)
    end
  end
end
