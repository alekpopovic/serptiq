# frozen_string_literal: true

require "test_helper"

class AccountProfileTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_identity_user(display_name: "Local Name")
    @identity = create_provider_identity(
      user: @user,
      provider: "github",
      provider_subject: "private-provider-subject",
      profile: { "name" => "Provider Name", "login" => "provider-login" }
    )
    authenticate_request(issue_identity_session(user: @user))
  end

  test "shows and updates only allowlisted local profile basics" do
    get account_profile_path

    assert_response :success
    assert_select "label", text: "Display name"
    assert_select "label", text: "Language"
    assert_select "label", text: "Time zone"
    refute_includes response.body, @identity.provider_subject
    refute_includes response.body, "provider-login"

    patch account_profile_path,
      params: {
        user: {
          display_name: "Updated Local Name",
          locale: "en",
          time_zone: "Belgrade",
          primary_email: "attacker@example.test"
        }
      }

    assert_response :see_other
    assert_equal "Updated Local Name", @user.reload.display_name
    assert_equal "Belgrade", @user.time_zone
    refute_equal "attacker@example.test", @user.primary_email
    assert_equal "Provider Name", @identity.reload.profile.fetch("name")
  end

  test "invalid local values render accessible errors without storing hostile markup" do
    hostile = "<script>alert(1)</script>" * 20

    patch account_profile_path,
      params: { user: { display_name: hostile, locale: "unsupported", time_zone: "Not/AZone" } }

    assert_response :unprocessable_content
    assert_select "[role='alert'][aria-labelledby='profile-errors-title']"
    assert_select "script", text: /alert\(1\)/, count: 0
    refute_includes response.body, "<script>alert(1)</script>"
    refute_includes @user.reload.display_name, "script"
  end
end
