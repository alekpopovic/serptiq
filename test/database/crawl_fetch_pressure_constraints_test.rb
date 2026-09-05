# frozen_string_literal: true

require "test_helper"

class CrawlFetchPressureConstraintsTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @now = Time.current.change(usec: 0)
    @owner = create_organization_for(slug: "pressure-constraints")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    project = create_project_for(@owner, slug: "pressure-constraints-project")
    property = create_property_for(@owner, project: project)
    @scan = create_scan_for(@owner, project: project, property: property, at: @now - 2.minutes)
    @scan = run_scan_to(@scan, "running", at: @now - 1.minute)
    result = Crawling::Public.discover_frontier(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      entries: [ Crawling::FrontierEntry.new(
        url: "https://constraints.example.com/",
        depth: 0,
        discovery_source: "seed"
      ) ],
      clock: -> { @now }
    )
    @lease = Crawling::LeaseFrontier.new(clock: -> { @now }).call(
      worker_id: "pressure-constraint-worker", limit: 1, lease_duration: 120
    ).sole
    context = Crawling::FetchPermitContext.new(
      organization_id: @lease.organization_id,
      scan_id: @lease.scan_id,
      crawl_url_id: result.items.sole.id,
      worker_id: @lease.worker_id,
      frontier_lease_token: @lease.token
    )
    @decision = Crawling::AcquireFetchPermit.new(
      clock: -> { @now }, emitter: ->(*) { }
    ).call(context: context, url: @lease.fetch_url)
  end

  test "database rejects malformed scope grant throttle and permit lifecycle shapes" do
    assert_database_rejects do
      Crawling::PressureState.insert!({
        scope_type: "host",
        scope_key_digest: "a" * 64,
        organization_id: @owner.organization.id,
        next_fetch_at: @now,
        created_at: @now,
        updated_at: @now
      })
    end
    assert_database_rejects do
      Crawling::ControlAccessGrant.insert!({
        user_id: @owner.membership.user_id,
        permission: "scans.run",
        granted_at: @now,
        created_at: @now,
        updated_at: @now
      })
    end
    assert_database_rejects do
      Crawling::Scan.where(id: @scan.id).update_all(throttle_reason: "host_rate")
    end
    assert_database_rejects do
      Crawling::FetchPermit.where(id: @decision.permit.id).update_all(
        state: "expired",
        released_at: @now,
        release_outcome: "succeeded"
      )
    end
    assert_database_rejects do
      Crawling::FetchPermit.where(id: @decision.permit.id).update_all(
        state: "released",
        released_at: @now,
        release_outcome: "expired"
      )
    end
  end

  test "database enforces exact tenant frontier references and immutable permit provenance" do
    foreign = create_organization_for(slug: "pressure-constraints-foreign")

    assert_raises(Crawling::AccessDenied) do
      Crawling::ReleaseFetchPermit.new(clock: -> { @now + 1.second }, emitter: ->(*) { }).call(
        organization_id: foreign.organization.id,
        permit_id: @decision.permit.id,
        permit_token: @decision.permit.token,
        outcome: "succeeded",
        http_status_code: 200
      )
    end
    assert_database_rejects do
      Crawling::FetchPermit.where(id: @decision.permit.id).update_all(
        organization_id: foreign.organization.id
      )
    end
    assert_database_rejects do
      Crawling::FetchPermit.where(id: @decision.permit.id).delete_all
    end
    assert_equal @owner.organization.id, Crawling::FetchPermit.find(@decision.permit.id).organization_id
  end

  private

  def assert_database_rejects(&block)
    assert_raises(ActiveRecord::StatementInvalid) do
      ApplicationRecord.transaction(requires_new: true, &block)
    end
  end
end
