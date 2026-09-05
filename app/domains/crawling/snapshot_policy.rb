# frozen_string_literal: true

require "digest"

module Crawling
  class SnapshotPolicy
    def initialize(clock: -> { Time.current }, access: PolicyAccess.new,
      limit_resolver: ResolvePolicyLimits.new, normalizer: NormalizePolicy.new)
      @clock = clock
      @access = access
      @limit_resolver = limit_resolver
      @normalizer = normalizer
    end

    def call(actor_membership:, project_id:, property_id:, environment_id:, scan_id:)
      context = @access.call(
        actor_membership: actor_membership, project_id: project_id,
        property_id: property_id, environment_id: environment_id
      )
      validate_scan_id!(scan_id)
      validate_scan_scope!(scan_id, context)
      existing = PolicySnapshot.find_by(scan_id: scan_id)
      return verify_existing!(existing, context) if existing

      create_snapshot(context, scan_id)
    rescue ActiveRecord::RecordNotUnique
      verify_existing!(PolicySnapshot.find_by!(scan_id: scan_id), context)
    end

    private

    def create_snapshot(context, scan_id)
      PolicySet.transaction do
        policy_set = PolicySet.lock.find_by(identity(context.environment))
        raise Conflict.new(reason_code: "crawl_policy_not_configured") unless policy_set&.current_version&.positive?

        version = policy_set.current
        current_limits = @limit_resolver.call(
          organization_id: context.environment.organization_id, at: @clock.call
        )
        effective = @normalizer.call(
          attributes: version.configuration.to_h,
          origin: context.environment.origin,
          limits: current_limits
        )
        configuration = canonical_configuration(effective.as_json)
        PolicySnapshot.create!(
          scan_id: scan_id,
          **identity(context.environment),
          crawl_policy_version_id: version.id,
          policy_version: version.version,
          configuration: configuration,
          configuration_digest: Digest::SHA256.hexdigest(JSON.generate(configuration)),
          created_at: @clock.call
        )
      end
    end

    def verify_existing!(snapshot, context)
      expected = identity(context.environment)
      unless expected.all? { |key, value| snapshot.public_send(key).to_s == value.to_s }
        raise AccessDenied.new(reason_code: "crawl_policy_scope_unavailable")
      end

      snapshot
    end

    def validate_scan_id!(scan_id)
      raise ArgumentError, "scan ID is invalid" unless Shared::Public.application_uuid?(scan_id.to_s)
    end

    def validate_scan_scope!(scan_id, context)
      available = Scan.exists?(id: scan_id, **identity(context.environment))
      raise AccessDenied.new(reason_code: "crawl_policy_scope_unavailable") unless available
    end

    def identity(environment)
      {
        organization_id: environment.organization_id,
        project_id: environment.project_id,
        property_id: environment.property_id,
        environment_id: environment.id
      }
    end

    def canonical_configuration(configuration)
      configuration.keys.sort.to_h { |key| [ key, configuration.fetch(key) ] }.freeze
    end
  end
end
