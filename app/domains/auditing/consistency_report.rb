# frozen_string_literal: true

module Auditing
  class ConsistencyReport
    TARGET_SQL = <<~SQL.squish.freeze
      SELECT audit_events.id,
        CASE WHEN targets.id IS NULL THEN 'target_orphan' ELSE 'target_cross_tenant' END AS reason_code
      FROM audit_events
      LEFT JOIN organizations targets ON targets.id = audit_events.target_id
      WHERE audit_events.target_type = 'Organization' AND audit_events.target_id IS NOT NULL
        AND (targets.id IS NULL OR targets.id <> audit_events.organization_id)
      UNION ALL
      SELECT audit_events.id,
        CASE WHEN targets.id IS NULL THEN 'target_orphan' ELSE 'target_cross_tenant' END AS reason_code
      FROM audit_events
      LEFT JOIN memberships targets ON targets.id = audit_events.target_id
      WHERE audit_events.target_type = 'Membership' AND audit_events.target_id IS NOT NULL
        AND (targets.id IS NULL OR targets.organization_id <> audit_events.organization_id)
      UNION ALL
      SELECT audit_events.id,
        CASE WHEN targets.id IS NULL THEN 'target_orphan' ELSE 'target_cross_tenant' END AS reason_code
      FROM audit_events
      LEFT JOIN invitations targets ON targets.id = audit_events.target_id
      WHERE audit_events.target_type = 'Invitation' AND audit_events.target_id IS NOT NULL
        AND (targets.id IS NULL OR targets.organization_id <> audit_events.organization_id)
      UNION ALL
      SELECT audit_events.id,
        CASE WHEN targets.id IS NULL THEN 'target_orphan' ELSE 'target_cross_tenant' END AS reason_code
      FROM audit_events
      LEFT JOIN teams targets ON targets.id = audit_events.target_id
      WHERE audit_events.target_type = 'Team' AND audit_events.target_id IS NOT NULL
        AND (targets.id IS NULL OR targets.organization_id <> audit_events.organization_id)
      UNION ALL
      SELECT audit_events.id,
        CASE WHEN targets.id IS NULL THEN 'target_orphan' ELSE 'target_cross_tenant' END AS reason_code
      FROM audit_events
      LEFT JOIN team_memberships targets ON targets.id = audit_events.target_id
      WHERE audit_events.target_type = 'TeamMembership' AND audit_events.target_id IS NOT NULL
        AND (targets.id IS NULL OR targets.organization_id <> audit_events.organization_id)
      UNION ALL
      SELECT audit_events.id,
        CASE WHEN targets.id IS NULL THEN 'target_orphan' ELSE 'target_cross_tenant' END AS reason_code
      FROM audit_events
      LEFT JOIN role_assignments targets ON targets.id = audit_events.target_id
      WHERE audit_events.target_type = 'RoleAssignment' AND audit_events.target_id IS NOT NULL
        AND (targets.id IS NULL OR targets.organization_id <> audit_events.organization_id)
      UNION ALL
      SELECT audit_events.id,
        CASE WHEN targets.id IS NULL THEN 'target_orphan' ELSE 'target_cross_tenant' END AS reason_code
      FROM audit_events
      LEFT JOIN organization_ownerships targets ON targets.id = audit_events.target_id
      WHERE audit_events.target_type = 'OrganizationOwnership' AND audit_events.target_id IS NOT NULL
        AND (targets.id IS NULL OR targets.organization_id <> audit_events.organization_id)
      UNION ALL
      SELECT audit_events.id,
        CASE WHEN targets.id IS NULL THEN 'target_orphan' ELSE 'target_cross_tenant' END AS reason_code
      FROM audit_events
      LEFT JOIN projects targets ON targets.id = audit_events.target_id
      WHERE audit_events.target_type = 'Project' AND audit_events.target_id IS NOT NULL
        AND (targets.id IS NULL OR targets.organization_id <> audit_events.organization_id)
      UNION ALL
      SELECT audit_events.id, 'target_orphan' AS reason_code
      FROM audit_events LEFT JOIN roles targets ON targets.id = audit_events.target_id
      WHERE audit_events.target_type = 'Role' AND audit_events.target_id IS NOT NULL AND targets.id IS NULL
      UNION ALL
      SELECT audit_events.id, 'target_orphan' AS reason_code
      FROM audit_events LEFT JOIN identities targets ON targets.id = audit_events.target_id
      WHERE audit_events.target_type = 'Identity' AND audit_events.target_id IS NOT NULL AND targets.id IS NULL
      UNION ALL
      SELECT audit_events.id, 'target_orphan' AS reason_code
      FROM audit_events LEFT JOIN users targets ON targets.id = audit_events.target_id
      WHERE audit_events.target_type = 'User' AND audit_events.target_id IS NOT NULL AND targets.id IS NULL
    SQL

    def call
      issues = actor_issues
      issues.concat(build(connection.exec_query(TARGET_SQL)))
      issues.sort_by { |issue| [ issue.audit_event_id, issue.reason_code ] }.freeze
    end

    private

    def actor_issues
      rows = connection.exec_query(<<~SQL.squish)
        SELECT audit_events.id,
          CASE
            WHEN memberships.id IS NULL THEN 'actor_membership_orphan'
            WHEN memberships.organization_id <> audit_events.organization_id THEN 'actor_membership_cross_tenant'
          END AS reason_code
        FROM audit_events
        LEFT JOIN memberships ON memberships.id = audit_events.actor_membership_id
        WHERE audit_events.actor_type = 'Membership'
          AND (memberships.id IS NULL OR memberships.organization_id <> audit_events.organization_id)
      SQL
      build(rows)
    end

    def build(rows)
      rows.map do |row|
        ConsistencyIssue.new(audit_event_id: row.fetch("id"), reason_code: row.fetch("reason_code"))
      end
    end

    def connection
      AuditEvent.connection
    end
  end
end
