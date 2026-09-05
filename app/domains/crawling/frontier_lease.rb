# frozen_string_literal: true

module Crawling
  FrontierLease = Data.define(
    :id, :organization_id, :project_id, :property_id, :environment_id, :scan_id,
    :normalized_url, :normalized_url_digest, :normalization_version, :host_digest,
    :depth, :priority, :attempts, :maximum_attempts, :worker_id, :token, :expires_at
  ) do
    def initialize(**attributes)
      %i[
        organization_id project_id property_id environment_id scan_id normalized_url
        normalized_url_digest host_digest worker_id token
      ].each { |name| attributes[name] = attributes.fetch(name).to_s.freeze }
      %i[id normalization_version depth priority attempts maximum_attempts].each do |name|
        attributes[name] = Integer(attributes.fetch(name))
      end
      super(**attributes)
      freeze
    end
  end
end
