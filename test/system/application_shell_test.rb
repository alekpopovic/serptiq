# frozen_string_literal: true

require "application_system_test_case"

class ApplicationShellSystemTest < ApplicationSystemTestCase
  test "keyboard user can reach and activate the skip link" do
    visit root_path
    stylesheets = page.evaluate_script("Array.from(document.styleSheets).map((sheet) => sheet.href)")
    assert stylesheets.compact.any? { |href| href.include?("tailwind") }, stylesheets.inspect
    stylesheet_rules = page.evaluate_script("Array.from(document.styleSheets).map((sheet) => [sheet.href, sheet.cssRules.length])")
    assert_equal "fixed", page.evaluate_script("getComputedStyle(document.querySelector('.so-skip-link')).position"), stylesheet_rules.inspect

    find("body").send_keys(:tab)
    assert_equal "Skip to main content", page.evaluate_script("document.activeElement.textContent.trim()")

    page.driver.browser.switch_to.active_element.send_keys(:enter)
    assert_equal "#main-content", page.evaluate_script("window.location.hash")
  end

  test "sign in page exposes provider readiness without collecting a password" do
    visit sign_in_path

    assert_text "Sign in to SearchOps"
    assert_text "Google sign-in is not configured"
    assert_text "GitHub sign-in is not configured"
    assert_no_selector "input[type='password']"
  end

  test "workspace navigation adapts to a narrow viewport" do
    page.current_window.resize_to(390, 844)
    authenticate_system_browser(issue_identity_session)
    visit dashboard_path

    assert_selector "aside[aria-label='Workspace']", visible: :hidden
    find("summary[aria-label='Open workspace navigation']").click
    assert_selector "details[open] nav[aria-label='Workspace navigation']"
    assert_link "Dashboard"

    page.current_window.resize_to(1400, 1000)
    assert_selector "aside[aria-label='Workspace']", visible: :visible
  end
end
