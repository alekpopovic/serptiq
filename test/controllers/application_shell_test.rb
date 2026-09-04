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

  test "sign in page reports provider readiness without collecting a password" do
    get sign_in_path, params: { return_to: "https://attacker.example/phish" }

    assert_response :success
    assert_select "h1", "Sign in to SearchOps"
    assert_select "p", /Google sign-in is not configured/
    assert_select "p", /GitHub sign-in is not available yet/
    assert_select "input[type='password']", count: 0
    assert_not_includes response.body, "attacker.example"
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
