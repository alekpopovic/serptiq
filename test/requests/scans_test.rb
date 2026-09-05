# frozen_string_literal: true

require "test_helper"

class ScansRequestTest < ActionDispatch::IntegrationTest
  setup do
    Authorization::Public.sync_catalog
    @user = create_identity_user(display_name: "Scan Owner")
    @owner = create_organization_for(user: @user, slug: "scan-workspace")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "scan-project")
    @property = create_property_for(@owner, project: @project)
    @scan = create_scan_for(@owner, project: @project, property: @property)
    authenticate_request(issue_identity_session(user: @user))
  end

  test "authorized project scan list and detail expose bounded aggregate observations" do
    get organization_project_scans_path(@owner.organization.slug, @project.slug)

    assert_response :success
    assert_select "h1", text: "Scans"
    assert_includes response.body, @scan.id
    assert_includes response.body, "Requested"
    refute_includes response.body, "solid_queue"

    get organization_project_scan_path(@owner.organization.slug, @project.slug, @scan.id)

    assert_response :success
    assert_select "turbo-cable-stream-source"
    assert_select "div#scan_progress_#{@scan.id}[aria-live='polite']"
    assert_select "h2", text: "Live crawl progress"
    assert_select "dt", text: "HTTP observations"
    assert_select "dt", text: "Page snapshots"
    assert_select "h2", text: "Immutable provenance"
    assert_select "button", text: "Request cancellation"
    assert_includes response.body, "Individual failures"
  end

  test "scan detail describes throttling as a bounded observation rather than a guarantee" do
    observed_at = Time.current.change(usec: 0)
    @scan.update!(
      throttled_at: observed_at,
      throttle_reason: "host_backoff",
      throttle_until: observed_at + 30.seconds
    )

    get organization_project_scan_path(@owner.organization.slug, @project.slug, @scan.id)

    assert_response :success
    assert_includes response.body, "currently observed as throttled"
    assert_includes response.body, "Host backoff"
    assert_includes response.body, "not a guaranteed resume time"
    refute_includes response.body, "example.com"
  end

  test "cancel action records immediate cancellation and cannot reopen the terminal scan" do
    assert_difference("Crawling::ScanEvent.count", 1) do
      patch cancel_organization_project_scan_path(
        @owner.organization.slug, @project.slug, @scan.id
      )
    end

    assert_redirected_to organization_project_scan_path(
      @owner.organization.slug, @project.slug, @scan.id
    )
    assert_equal "canceled", @scan.reload.status

    get organization_project_scan_path(@owner.organization.slug, @project.slug, @scan.id)
    assert_response :success
    assert_select "button", text: "Request cancellation", count: 0
  end

  test "manual admission accepts a bounded command and returns a stable JSON scan contract" do
    captured = nil
    scan = @scan
    operation = ->(**attributes) do
      captured = attributes
      scan
    end

    with_admit_scan(operation) do
      post organization_project_scans_path(
        @owner.organization.slug, @project.slug, format: :json
      ), params: {
        scan_request: {
          idempotency_key: "request-api-one",
          property_id: @property.id,
          environment_id: @property.environments.sole.id,
          scan_type: "full"
        }
      }
    end

    assert_response :accepted
    payload = response.parsed_body.fetch("scan")
    assert_equal @scan.id, payload.fetch("id")
    assert_equal @project.id, payload.fetch("project_id")
    command = captured.fetch(:command)
    assert_instance_of Crawling::AdmissionRequest, command
    assert_equal "manual", command.source
    assert_equal @owner.membership.id, captured.fetch(:actor_membership).id
  end

  test "admission exposes stable unverified capacity unsafe and quota error contracts" do
    cases = [
      [ Crawling::VerificationRequired.new, :conflict, "verification_required" ],
      [ Crawling::CapacityExceeded.new(scope: "organization"), :conflict, "scan_capacity_exceeded" ],
      [ Crawling::TargetUnsafe.new, :unprocessable_content, "unsafe_target" ],
      [ Shared::Public::QuotaError.new(reason_code: "usage_quota_exceeded"), :too_many_requests, "quota_exceeded" ]
    ]

    cases.each_with_index do |(error, status, code), index|
      operation = ->(**) { raise error }
      with_admit_scan(operation) do
        post organization_project_scans_path(
          @owner.organization.slug, @project.slug, format: :json
        ), params: {
          scan_request: {
            idempotency_key: "request-api-error-#{index}",
            property_id: @property.id,
            environment_id: @property.environments.sole.id,
            scan_type: "full"
          }
        }
      end

      assert_response status
      assert_equal code, response.parsed_body.dig("error", "code")
      assert_equal code, response.headers.fetch("X-SearchOps-Error-Code")
    end
  end

  test "nested scan substitution and another tenant project fail closed without leaking scan data" do
    sibling = create_project_for(@owner, slug: "scan-project-sibling")
    get organization_project_scan_path(@owner.organization.slug, sibling.slug, @scan.id)
    assert_response :forbidden
    refute_includes response.body, @scan.settings_digest

    foreign = create_organization_for(slug: "scan-workspace-foreign")
    enable_project_limit(foreign)
    foreign_project = create_project_for(foreign, slug: "scan-project-foreign")
    get organization_project_scans_path(@owner.organization.slug, foreign_project.slug)
    assert_response :forbidden
    refute_includes response.body, foreign_project.name
  end

  test "project viewer can read scans but cannot see or invoke cancellation" do
    viewer_user = create_identity_user(display_name: "Scan Viewer")
    viewer = Tenancy::Public.create_membership(
      actor_membership: @owner.membership,
      user: viewer_user
    )
    Authorization::Public.assign_role(
      actor_membership: @owner.membership,
      grantee_type: "Membership",
      grantee_id: viewer.id,
      role_id: Authorization::Role.find_by!(system: true, key: "viewer").id,
      scope_type: "Project",
      scope_id: @project.id
    )
    reset!
    authenticate_request(issue_identity_session(user: viewer_user))

    get organization_project_scan_path(@owner.organization.slug, @project.slug, @scan.id)
    assert_response :success
    assert_select "button", text: "Request cancellation", count: 0

    patch cancel_organization_project_scan_path(
      @owner.organization.slug, @project.slug, @scan.id
    )
    assert_response :forbidden
    assert_equal "requested", @scan.reload.status

    post organization_project_scans_path(
      @owner.organization.slug, @project.slug, format: :json
    ), params: {
      scan_request: {
        idempotency_key: "viewer-forbidden",
        property_id: @property.id,
        environment_id: @property.environments.sole.id,
        scan_type: "full"
      }
    }
    assert_response :forbidden
    assert_equal "authorization_denied", response.parsed_body.dig("error", "code")
  end

  private

  def with_admit_scan(operation)
    original = Crawling::Public.method(:admit_scan)
    Crawling::Public.define_singleton_method(:admit_scan, &operation)
    yield
  ensure
    Crawling::Public.define_singleton_method(:admit_scan) do |**attributes|
      original.call(**attributes)
    end
  end
end
