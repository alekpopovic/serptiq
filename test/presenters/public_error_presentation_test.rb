# frozen_string_literal: true

require "test_helper"

class PublicErrorPresentationTest < ActiveSupport::TestCase
  test "maps consent expiry collision outage and internal failures to safe actions" do
    cases = [
      [
        Identity::ProviderError.new(category: "access_denied", operation: "authorization_response"),
        "Sign-in was cancelled", :sign_in
      ],
      [ Identity::ExpiredOauthTransaction.new, "no longer valid", :sign_in ],
      [ Identity::AccountLinkRequired.new, "Account confirmation is required", :sign_in ],
      [
        Identity::ProviderError.new(category: "unavailable", operation: "token_exchange"),
        "temporarily unavailable", :sign_in
      ],
      [ RuntimeError.new("private internal detail"), "Something went wrong", :home ]
    ]

    cases.each do |error, title, action|
      mapping = Shared::Errors.http_response_for(error)
      presentation = PublicErrorPresentation.call(error, mapping)
      assert_includes presentation.title, title
      assert_equal action, presentation.action
      refute_includes presentation.message, error.message if error.is_a?(RuntimeError)
    end
  end
end
