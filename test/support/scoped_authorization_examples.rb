# frozen_string_literal: true

module TestSupport
  module ScopedAuthorizationExamples
    def assert_project_scope_access(actor:, organization:, permission:, allowed:, denied:)
      Array(allowed).each do |project|
        result = scoped_decision(
          actor: actor, organization: organization, permission: permission, project: project
        )
        assert result.allow?, "expected #{permission} for project #{project.id}: #{result.reason_code}"
      end
      Array(denied).each do |project|
        result = scoped_decision(
          actor: actor, organization: organization, permission: permission, project: project
        )
        assert result.deny?, "expected #{permission} denial for project #{project.id}"
      end
    end

    def assert_property_scope_access(actor:, organization:, permission:, allowed:, denied:)
      Array(allowed).each do |project, property|
        result = scoped_decision(
          actor: actor,
          organization: organization,
          permission: permission,
          project: project,
          property: property
        )
        assert result.allow?, "expected #{permission} for property #{property.id}: #{result.reason_code}"
      end
      Array(denied).each do |project, property|
        result = scoped_decision(
          actor: actor,
          organization: organization,
          permission: permission,
          project: project,
          property: property
        )
        assert result.deny?, "expected #{permission} denial for property #{property.id}"
      end
    end

    private

    def scoped_decision(actor:, organization:, permission:, project: nil, property: nil)
      Authorization::Public.decision(
        actor_membership: actor,
        permission_key: permission,
        organization: organization,
        project: project,
        property: property
      )
    end
  end
end
