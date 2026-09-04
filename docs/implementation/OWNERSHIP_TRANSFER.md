# Ownership transfer

Organization ownership is the explicit `organization_ownerships` relationship introduced with the tenancy
aggregate. Each organization points to its current assignment, the database permits only one active assignment,
and historical assignments retain attribution. Generic role assignment cannot create ownership.

Only the current owner can obtain an `organization.transfer` decision. The transfer endpoint is POST-only and
requires the exact confirmation statement plus an active session authenticated within the previous 15 minutes.
The service locks the session, organization, current assignment, actor and target membership. The target must be
an active member of the same organization.

Within one PostgreSQL transaction the service creates the replacement assignment, moves the organization's
pointer, closes the prior assignment, activates the replacement, revokes the new owner's existing sessions and
rotates the previous owner's current session while revoking their other sessions. Any failure rolls the complete
change back. Permission decisions are intentionally uncached, so both users' next decisions reflect ownership
immediately. The previous owner remains an active member but receives no automatic administrative role.

Successful and rejected attempts emit error-severity security records with keyed hashes rather than raw tenant
or membership IDs. `ownership_transfer_notification.tenancy` is the internal notification hook for a later
delivery adapter; it carries the exact organization and user IDs to trusted in-process subscribers and is not a
customer-visible delivery guarantee.

Support recovery does not use a direct database backdoor. Support verifies control of the current owner's
account through the incident process, preserves evidence, restores that owner's ability to authenticate, and
then requires the normal recent-authenticated transfer. If no current owner can authenticate, ownership change
remains blocked until a separately designed and reviewed legal-recovery workflow exists; there is no standing
support role, direct SQL procedure or silent ownership mutation.
