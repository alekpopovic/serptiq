# frozen_string_literal: true

require "test_helper"

class ApplicationShellRequestTest < ActionDispatch::IntegrationTest
  test "public home has semantic landmarks and honest scaffold language" do
    get root_path

    assert_response :success
    assert_select "html[lang='en']"
    assert_select "a.so-skip-link[href='#main-content']", text: "Skip to main content"
    assert_select "header nav[aria-label='Primary']"
    assert_select "main#main-content[tabindex='-1']"
    assert_select "footer"
    assert_select "h1", /accessible shell/
    assert_select ".so-badge", text: "Foundation scaffold"
  end

  test "sign in validation is server rendered and associates its summary and field error" do
    post sign_in_path, params: { shell_sign_in_form: { provider: "" } }

    assert_response :unprocessable_content
    assert_select "[role='alert'][tabindex='-1'][data-controller='focus']"
    assert_select "[role='alert'] a[href='#shell_sign_in_form_provider_google']", /Provider/
    assert_select "fieldset[aria-describedby~='provider-error']"
    assert_select "#provider-error", /Choose Google or GitHub/
    assert_select "form[action='#{sign_in_path}'][method='post']"
  end

  test "hostile provider input is rejected and not reflected" do
    hostile_provider = %(<script>alert("unsafe")</script>)

    post sign_in_path, params: { shell_sign_in_form: { provider: hostile_provider } }

    assert_response :unprocessable_content
    assert_select "#provider-error", /Choose Google or GitHub/
    assert_not_includes response.body, hostile_provider
  end

  test "dashboard uses authenticated shell scaffolding without tenant fixtures" do
    authenticate_request(issue_identity_session)

    get dashboard_path

    assert_response :success
    assert_select "aside[aria-label='Workspace']"
    assert_select "header details summary[aria-label='Open workspace navigation']"
    assert_select "nav[aria-label='Workspace navigation'] a[aria-current='page']", text: "Dashboard"
    assert_select "turbo-frame#dashboard-shell"
    assert_select "#workspace-empty-title", text: "No workspace context yet"
    assert_select ".so-badge", text: "Signed in"
  end
end
