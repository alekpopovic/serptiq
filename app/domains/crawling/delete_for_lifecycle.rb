# frozen_string_literal: true

module Crawling
  class DeleteForLifecycle
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(organization_id:, project_id:, deletion_workflow_id:, property_id: nil)
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
      CrawlUrl.where(scan_id: scan_ids).delete_all if scan_ids.any?
      ScanEvent.where(scan_id: scan_ids).delete_all if scan_ids.any?
      scans.delete_all
      set_ids = set_targets.map(&:first)
      PolicyVersion.where(crawl_policy_set_id: set_ids).delete_all if set_ids.any?
      sets.delete_all
      set_ids.length + scan_ids.length
    end
  end
end
