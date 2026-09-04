# frozen_string_literal: true

module Tenancy
  class OwnershipConsistency
    SQL = <<~SQL.squish.freeze
      SELECT organizations.id,
        CASE
          WHEN current_ownership.id IS NULL THEN 'current_ownership_invalid'
          WHEN current_membership.id IS NULL THEN 'current_owner_membership_inactive'
          WHEN active_ownerships.total <> 1 THEN 'active_ownership_count_invalid'
        END AS reason_code
      FROM organizations
      LEFT JOIN organization_ownerships current_ownership
        ON current_ownership.id = organizations.current_ownership_id
        AND current_ownership.organization_id = organizations.id
        AND current_ownership.ended_at IS NULL
        AND current_ownership.current = true
        AND current_ownership.membership_status = 'active'
      LEFT JOIN memberships current_membership
        ON current_membership.id = current_ownership.membership_id
        AND current_membership.organization_id = organizations.id
        AND current_membership.status = 'active'
      LEFT JOIN LATERAL (
        SELECT COUNT(*) AS total
        FROM organization_ownerships
        WHERE organization_ownerships.organization_id = organizations.id
          AND organization_ownerships.ended_at IS NULL
      ) active_ownerships ON TRUE
      WHERE current_ownership.id IS NULL
        OR current_membership.id IS NULL
        OR active_ownerships.total <> 1
      ORDER BY organizations.id
    SQL

    def call
      Organization.connection.select_all(SQL).map do |row|
        OwnershipConsistencyIssue.new(
          organization_id: row.fetch("id"),
          reason_code: row.fetch("reason_code")
        )
      end.freeze
    end
  end
end
