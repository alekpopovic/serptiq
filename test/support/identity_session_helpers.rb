# frozen_string_literal: true

module TestSupport
  module IdentitySessionHelpers
    def create_identity_user(**attributes)
      defaults = {
        primary_email: "user-#{SecureRandom.hex(6)}@example.test",
        display_name: "Test User"
      }
      Identity::User.create!(**defaults.merge(attributes))
    end

    def issue_identity_session(user: create_identity_user, at: Time.current, metadata: Identity::SessionMetadata.empty)
      Identity::Public.issue_session(user: user, metadata: metadata, clock: -> { at })
    end

    def authenticate_request(issued_session)
      cookies[Identity::SessionCookie.name] = issued_session.token
    end

    def authenticate_system_browser(issued_session)
      visit root_path
      page.driver.browser.manage.add_cookie(
        name: Identity::SessionCookie.name,
        value: issued_session.token,
        path: "/"
      )
    end
  end
end
