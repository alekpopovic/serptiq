# frozen_string_literal: true

module Crawling
  class ReadRobotsSitemaps
    def call(organization_id:, scan_id:)
      snapshot = RobotsSnapshot.find_by!(organization_id: organization_id, scan_id: scan_id)
      snapshot.sitemap_urls.map do |url|
        RobotsSitemapCandidate.new(
          url: url,
          snapshot_id: snapshot.id,
          artifact_sha256: snapshot.artifact_sha256,
          trusted: false
        )
      end.freeze
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "robots_scope_unavailable"), cause: nil
    end
  end
end
