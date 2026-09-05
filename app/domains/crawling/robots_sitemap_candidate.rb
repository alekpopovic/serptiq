# frozen_string_literal: true

module Crawling
  RobotsSitemapCandidate = Data.define(:url, :snapshot_id, :artifact_sha256, :trusted) do
    def initialize(url:, snapshot_id:, artifact_sha256:, trusted: false)
      super(
        url: url.to_s.freeze,
        snapshot_id: snapshot_id.to_s.freeze,
        artifact_sha256: artifact_sha256&.to_s&.freeze,
        trusted: trusted == true
      )
      freeze
    end

    def trusted?
      trusted
    end
  end
end
