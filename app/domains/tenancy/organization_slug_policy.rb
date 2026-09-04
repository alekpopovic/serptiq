# frozen_string_literal: true

module Tenancy
  module OrganizationSlugPolicy
    RESERVED = %w[
      account billing invitations members new projects roles security settings switch teams
    ].freeze
    NAMESPACE_LOCK_ID = 5_348_454_698_114_295_322

    module_function

    def reserved?(value)
      RESERVED.include?(OrganizationSlug.call(value))
    end

    def claimed_by_alias?(value, excluding_organization_id: nil)
      relation = OrganizationSlugAlias.where(slug: OrganizationSlug.call(value))
      relation = relation.where.not(organization_id: excluding_organization_id) if excluding_organization_id
      relation.exists?
    end

    def with_namespace_lock
      raise ArgumentError, "slug namespace lock requires a transaction" unless Organization.connection.transaction_open?

      Organization.connection.execute("SELECT pg_advisory_xact_lock(#{NAMESPACE_LOCK_ID})")
      yield
    end
  end
end
