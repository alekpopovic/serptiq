# frozen_string_literal: true

require "digest"

module Crawling
  class PressureStateKey
    GLOBAL_DIGEST = Digest::SHA256.hexdigest("crawl-pressure:v1:global").freeze

    def global
      attributes("global", GLOBAL_DIGEST)
    end

    def organization(scan)
      attributes(
        "organization",
        digest("organization", scan.organization_id),
        organization_id: scan.organization_id
      )
    end

    def scan(scan)
      attributes(
        "scan",
        digest("scan", scan.organization_id, scan.id),
        organization_id: scan.organization_id,
        project_id: scan.project_id,
        property_id: scan.property_id,
        environment_id: scan.environment_id,
        scan_id: scan.id
      )
    end

    def host(host_key)
      attributes("host", host_key.digest, host_key_digest: host_key.digest)
    end

    private

    def digest(scope, *identifiers)
      Digest::SHA256.hexdigest([ "crawl-pressure:v1", scope, *identifiers ].join(":"))
    end

    def attributes(scope, key, **identifiers)
      { scope_type: scope, scope_key_digest: key, **identifiers }.freeze
    end
  end
end
