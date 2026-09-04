# frozen_string_literal: true

require "test_helper"

class SharedRedactionTest < ActiveSupport::TestCase
  test "redacts nested parameters and structured events" do
    value = {
      "provider" => "google",
      "oauth" => { "code" => "oauth-code", "access_token" => "access-token" },
      "page_credentials" => { "username" => "customer", "password" => "page-password" }
    }

    filtered = redaction.structured_event(value)

    assert_equal "google", filtered.fetch("provider")
    assert_equal "[FILTERED]", filtered.dig("oauth", "code")
    assert_equal "[FILTERED]", filtered.dig("oauth", "access_token")
    assert_equal "[FILTERED]", filtered.fetch("page_credentials")
  end

  test "redacts authorization cookies API keys and webhook signatures in headers" do
    filtered = redaction.headers(
      "Authorization" => "Bearer secret",
      "Cookie" => "session=secret",
      "X-Api-Key" => "api-secret",
      "X-Webhook-Signature" => "signature",
      "Accept" => "application/json"
    )

    assert_equal "application/json", filtered.fetch("Accept")
    assert_equal [ "[FILTERED]" ], filtered.values_at("Authorization", "Cookie", "X-Api-Key", "X-Webhook-Signature").uniq
  end

  test "registers the same sensitive fields with Rails parameter filtering" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    assert_equal "[FILTERED]", filter.filter("oauth_code" => "secret").fetch("oauth_code")
    assert_equal "[FILTERED]", filter.filter("X-Api-Key" => "secret").fetch("X-Api-Key")
  end

  test "removes URL credentials and redacts only sensitive query values" do
    filtered = redaction.url("https://user:password@example.com/callback?code=oauth-code&scope=read&api_key=secret")

    assert_equal "https://example.com/callback?code=%5BFILTERED%5D&scope=read&api_key=%5BFILTERED%5D", filtered
  end

  test "does not echo an invalid URL" do
    assert_equal "[FILTERED_URL]", redaction.url("https://example.com/%zz?token=secret")
  end

  private

  def redaction
    Rails.application.config.x.redaction
  end
end
