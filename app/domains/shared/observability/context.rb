# frozen_string_literal: true

module Shared
  module Observability
    class Context < ActiveSupport::CurrentAttributes
      CORRELATION_ID_PATTERN = /\A[a-zA-Z0-9][a-zA-Z0-9_.:-]{0,127}\z/
      RESOURCE_ID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i
      HASH_PATTERN = /\A[0-9a-f]{24}\z/
      FIELDS = %i[
        request_id trace_id job_id release environment organization_id_hash project_id scan_id
        actor_id_hash subject_id_hash role_id_hash scope_id_hash principal_type scope_type
      ].freeze

      attribute(*FIELDS)

      class << self
        def snapshot
          instance.attributes.compact.transform_keys(&:to_s).freeze
        end

        def normalize_correlation_id(value, fallback: nil)
          candidate = value.to_s
          return candidate.freeze if CORRELATION_ID_PATTERN.match?(candidate)

          fallback
        end

        def attach_resources(organization_id: nil, project_id: nil, scan_id: nil, identifier_hasher: nil)
          if organization_id
            hasher = identifier_hasher || IdentifierHasher.default
            self.organization_id_hash = normalize_organization_hash(hasher.call(organization_id))
          end
          self.project_id = normalize_resource_id(:project_id, project_id) if project_id
          self.scan_id = normalize_resource_id(:scan_id, scan_id) if scan_id
          snapshot
        end

        def with_audit_principals(actor_id:, subject_id:, identifier_hasher: nil)
          hasher = identifier_hasher || IdentifierHasher.default
          attributes = {
            actor_id_hash: actor_id && normalize_identifier_hash(hasher.call(actor_id)),
            subject_id_hash: subject_id && normalize_identifier_hash(hasher.call(subject_id))
          }
          set(attributes) { yield }
        end

        def with_tenant_audit(organization_id:, actor_id:, subject_id:, identifier_hasher: nil)
          hasher = identifier_hasher || IdentifierHasher.default
          attributes = {
            organization_id_hash: organization_id && normalize_organization_hash(hasher.call(organization_id)),
            actor_id_hash: actor_id && normalize_identifier_hash(hasher.call(actor_id)),
            subject_id_hash: subject_id && normalize_identifier_hash(hasher.call(subject_id))
          }
          set(attributes) { yield }
        end

        def with_authorization_audit(organization_id:, actor_id:, principal_id:, role_id:, scope_id:,
          principal_type:, scope_type:, identifier_hasher: nil)
          hasher = identifier_hasher || IdentifierHasher.default
          attributes = {
            organization_id_hash: normalize_organization_hash(hasher.call(organization_id)),
            actor_id_hash: normalize_identifier_hash(hasher.call(actor_id)),
            subject_id_hash: normalize_identifier_hash(hasher.call(principal_id)),
            role_id_hash: normalize_identifier_hash(hasher.call(role_id)),
            scope_id_hash: normalize_identifier_hash(hasher.call(scope_id)),
            principal_type: principal_type.to_s.downcase,
            scope_type: scope_type.to_s.downcase
          }
          set(attributes) { yield }
        end

        def with_authorization_decision(organization_id:, actor_id:, scope_id:, scope_type:,
          identifier_hasher: nil)
          hasher = identifier_hasher || IdentifierHasher.default
          attributes = {
            organization_id_hash: organization_id && normalize_organization_hash(hasher.call(organization_id)),
            actor_id_hash: actor_id && normalize_identifier_hash(hasher.call(actor_id)),
            scope_id_hash: scope_id && normalize_identifier_hash(hasher.call(scope_id)),
            scope_type: scope_type.to_s.downcase.presence
          }
          set(attributes) { yield }
        end

        private

        def normalize_organization_hash(value)
          candidate = value.to_s
          raise ArgumentError, "organization hash must be a safe keyed digest" unless HASH_PATTERN.match?(candidate)

          candidate.freeze
        end

        def normalize_identifier_hash(value)
          candidate = value.to_s
          raise ArgumentError, "identifier hash must be a safe keyed digest" unless HASH_PATTERN.match?(candidate)

          candidate.freeze
        end

        def normalize_resource_id(name, value)
          candidate = value.respond_to?(:id) ? value.id.to_s : value.to_s
          raise ArgumentError, "#{name} must be an application UUID" unless RESOURCE_ID_PATTERN.match?(candidate)

          candidate.downcase.freeze
        end
      end
    end
  end
end
