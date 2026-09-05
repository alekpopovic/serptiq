# frozen_string_literal: true

module Crawling
  class DeleteForLifecycle
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(organization_id:, project_id:, deletion_workflow_id:, property_id: nil)
      Scan.transaction do
        delete_within_transaction(
          organization_id: organization_id,
          project_id: project_id,
          deletion_workflow_id: deletion_workflow_id,
          property_id: property_id
        )
      end
    end

    private

    def delete_within_transaction(organization_id:, project_id:, deletion_workflow_id:, property_id:)
      Scan.connection.execute(
        "SET CONSTRAINTS fk_crawl_urls_same_scan_fetch_result DEFERRED"
      )
      ensure_artifacts_deletable!(organization_id, project_id, property_id)
      scans = Scan.where(organization_id: organization_id, project_id: project_id)
      scans = scans.where(property_id: property_id) if property_id
      scan_targets = scans.order(:id).pluck(:id, :property_id)
      scan_targets.each do |scan_id, scan_property_id|
        Auditing::Public.record_target_tombstone!(
          organization_id: organization_id,
          deletion_workflow_id: deletion_workflow_id,
          target_type: "Scan",
          target_id: scan_id,
          project_id: project_id,
          property_id: scan_property_id,
          deleted_at: @clock.call
        )
      end

      sets = PolicySet.where(organization_id: organization_id, project_id: project_id)
      sets = sets.where(property_id: property_id) if property_id
      set_targets = sets.order(:id).pluck(:id, :property_id)
      set_targets.each do |set_id, set_property_id|
        Auditing::Public.record_target_tombstone!(
          organization_id: organization_id,
          deletion_workflow_id: deletion_workflow_id,
          target_type: "CrawlPolicy",
          target_id: set_id,
          project_id: project_id,
          property_id: set_property_id,
          deleted_at: @clock.call
        )
      end
      PolicySnapshot.where(organization_id: organization_id, project_id: project_id)
        .then { |relation| property_id ? relation.where(property_id: property_id) : relation }
        .delete_all
      scan_ids = scan_targets.map(&:first)
      FetchPermit.where(scan_id: scan_ids).delete_all if scan_ids.any?
      PressureState.where(scope_type: "scan", scan_id: scan_ids).delete_all if scan_ids.any?
      if scan_ids.any?
        PageSnapshot.where(scan_id: scan_ids).delete_all
        CrawlFetchResult.where(scan_id: scan_ids).delete_all
        StaticCrawlExecution.where(scan_id: scan_ids).delete_all
      end
      delete_artifact_metadata!(organization_id, project_id, property_id)
      RobotsSnapshot.where(scan_id: scan_ids).delete_all if scan_ids.any?
      SitemapEntry.where(scan_id: scan_ids).delete_all if scan_ids.any?
      SitemapFile.where(scan_id: scan_ids).order(index_depth: :desc).delete_all if scan_ids.any?
      SitemapDiscovery.where(scan_id: scan_ids).delete_all if scan_ids.any?
      CrawlUrl.where(scan_id: scan_ids).delete_all if scan_ids.any?
      ScanUsageOperation.where(scan_id: scan_ids).delete_all if scan_ids.any?
      ScanEvent.where(scan_id: scan_ids).delete_all if scan_ids.any?
      scans.delete_all
      set_ids = set_targets.map(&:first)
      PolicyVersion.where(crawl_policy_set_id: set_ids).delete_all if set_ids.any?
      sets.delete_all
      set_ids.length + scan_ids.length
    end

    def delete_artifact_metadata!(organization_id, project_id, property_id)
      artifacts = Artifact.where(organization_id: organization_id, project_id: project_id)
      artifacts = artifacts.where(property_id: property_id) if property_id
      if artifacts.where(legal_hold: true).exists?
        raise ArtifactLifecycleBlocked.new(
          "resource artifact deletion is paused by a legal hold",
          reason_code: "artifact_legal_hold"
        )
      end

      artifacts.delete_all
      blobs = ArtifactBlob.where(organization_id: organization_id, project_id: project_id)
      blobs = blobs.where(property_id: property_id) if property_id
      blobs.delete_all
    end

    def ensure_artifacts_deletable!(organization_id, project_id, property_id)
      artifacts = Artifact.where(organization_id: organization_id, project_id: project_id)
      artifacts = artifacts.where(property_id: property_id) if property_id
      return unless artifacts.where(legal_hold: true).exists?

      raise ArtifactLifecycleBlocked.new(
        "resource artifact deletion is paused by a legal hold",
        reason_code: "artifact_legal_hold"
      )
    end
  end
end
