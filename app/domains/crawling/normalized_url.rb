# frozen_string_literal: true

module Crawling
  NormalizedUrl = Data.define(
    :fetch_url, :identity_url, :origin, :scheme, :host, :port, :path,
    :normalization_version, :identity_digest, :host_digest
  ) do
    def initialize(**attributes)
      %i[
        fetch_url identity_url origin scheme host path identity_digest host_digest
      ].each { |name| attributes[name] = attributes.fetch(name).to_s.freeze }
      attributes[:port] = Integer(attributes.fetch(:port))
      attributes[:normalization_version] = Integer(attributes.fetch(:normalization_version))
      super(**attributes)
      freeze
    end
  end
end
