# frozen_string_literal: true

require "application_system_test_case"

class ScansSystemTest < ApplicationSystemTestCase
  test "owner reviews a real scan observation and requests cooperative cancellation" do
    Authorization::Public.sync_catalog
    user = create_identity_user(display_name: "Scan System Owner")
    owner = create_organization_for(user: user, slug: "scan-system-workspace")
    enable_project_limit(owner)
    enable_property_limits(owner)
    project = create_project_for(owner, slug: "scan-system-project")
    property = create_property_for(owner, project: project)
    scan = create_scan_for(owner, project: project, property: property)
    scan = run_scan_to(scan, "running")
    Crawling::Public.record_scan_progress(
      organization_id: scan.organization_id,
      scan_id: scan.id,
      checkpoint_key: "system-progress-001",
      counters: {
        targets_count: 1,
        urls_discovered_count: 4,
        urls_queued_count: 1,
        urls_running_count: 1,
        urls_processed_count: 2,
        urls_succeeded_count: 1,
        urls_failed_count: 1,
        urls_skipped_count: 0,
        findings_count: 2
      }
    )
    authenticate_system_browser(issue_identity_session(user: user))

    visit organization_project_path(owner.organization.slug, project.slug)
    assert_selector "turbo-frame#project_scan_status_scan-system-project [data-observation-state='loading']"
    click_link "View scans"
    click_link "View"

    assert_text "Running"
    assert_selector "section", text: /processed urls\s+2/i
    assert_text /individual failures/i
    accept_confirm { click_button "Request cancellation" }

    assert_text "Scan cancellation was recorded"
    assert_text "Cancel requested"
    assert_no_button "Request cancellation"
  end
end
