# frozen_string_literal: true

module Tenancy
  class IssueInvitation
    DEFAULT_EXPIRY = 7.days

    def initialize(clock: -> { Time.current }, rate_limiter: InvitationRateLimiter.new, delivery: nil)
      @clock = clock
      @rate_limiter = rate_limiter
      @delivery = delivery || method(:deliver)
    end

    def call(actor_membership:, email:, initial_role_key: nil)
      normalized_email = email.to_s.strip.downcase
      now = @clock.call
      consume_limits!(actor_membership, normalized_email)
      issued = Invitation.transaction do
        actor = lock_owner!(actor_membership)
        supersede_pending!(actor.organization_id, normalized_email, now)
        build_invitation(actor, normalized_email, initial_role_key, now)
      end
      @delivery.call(issued: issued, inviter: actor_membership)
      audit("invitation.issued", "succeeded", actor_membership, issued.invitation)
      issued
    rescue StandardError => error
      audit("invitation.issue_rejected", "denied", actor_membership, nil, error)
      raise
    end

    private

    def consume_limits!(actor, email)
      @rate_limiter.consume!(scope: "issue_actor", key: actor&.id)
      @rate_limiter.consume!(scope: "issue_destination", key: email)
    end

    def lock_owner!(actor_membership)
      raise OrganizationAccessDenied unless actor_membership.is_a?(Membership)

      actor = Membership.lock.find(actor_membership.id)
      AuthorizeOrganizationOwner.new.call(membership: actor)
      actor
    rescue ActiveRecord::RecordNotFound
      raise OrganizationAccessDenied, cause: nil
    end

    def supersede_pending!(organization_id, email, now)
      Invitation.lock.where(organization_id: organization_id, email: email, status: "pending").find_each do |invitation|
        invitation.update!(status: "superseded", superseded_at: now)
      end
    end

    def build_invitation(actor, email, initial_role_key, now)
      token = InvitationToken.generate
      access = initial_role_key.present? ? {
        initial_role_key: initial_role_key,
        initial_scope_type: "Organization",
        initial_scope_id: actor.organization_id
      } : {}
      invitation = Invitation.create!(
        organization_id: actor.organization_id,
        invited_by_membership_id: actor.id,
        email: email,
        token_digest: InvitationToken.digest(token),
        expires_at: now + DEFAULT_EXPIRY,
        created_at: now,
        updated_at: now,
        **access
      )
      IssuedInvitation.new(invitation: invitation, token: token)
    end

    def deliver(issued:, inviter:)
      OrganizationInvitationMailer.with(
        recipient: issued.invitation.email,
        organization_name: issued.invitation.organization.name,
        inviter_name: inviter.display_name,
        token: issued.token,
        expires_at: issued.invitation.expires_at
      ).invitation.deliver_now
    end

    def audit(name, outcome, actor, invitation, error = nil)
      Audit.emit(
        name,
        outcome: outcome,
        operation: "issue",
        reason_code: error.respond_to?(:reason_code) ? error.reason_code : nil,
        actor_membership_id: actor&.id,
        subject_membership_id: invitation&.accepted_by_membership_id
      )
    end
  end
end
