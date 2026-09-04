# frozen_string_literal: true

module Tenancy
  module Public
    module_function

    def first_run_status(user:)
      raise ArgumentError, "active identity user is required" unless Identity::Public.active_user?(user)

      kind = if OrganizationNavigation.new.call(user: user).any?
        :returning
      elsif pending_invitation_summaries(user: user).any?
        :invited
      else
        :no_organization
      end
      FirstRunStatus.new(kind: kind)
    end

    def pending_invitation_summaries(user:)
      emails = Identity::Public.verified_emails(user: user)
      return [].freeze if emails.empty?

      Invitation.includes(:organization)
        .where(email: emails, status: "pending", expires_at: Time.current..)
        .order(:expires_at, :id)
        .map { |invitation|
          InvitationSummary.new(
            organization_name: invitation.organization.name,
            expires_at: invitation.expires_at
          )
        }
        .freeze
    end

    def issue_invitation(actor_membership:, email:, initial_role_key: nil, authorization: nil)
      IssueInvitation.new.call(
        actor_membership: actor_membership,
        email: email,
        initial_role_key: initial_role_key,
        authorization: authorization
      )
    end

    def review_invitation(token:, user:)
      ReviewInvitation.new.call(token: token, user: user)
    end

    def accept_invitation(token:, user:, rate_limit_key:)
      AcceptInvitation.new.call(token: token, user: user, rate_limit_key: rate_limit_key)
    end

    def accept_invitation_with_access_intent(token:, user:, rate_limit_key:, &block)
      AcceptInvitation.new.call_with_intent(
        token: token, user: user, rate_limit_key: rate_limit_key, &block
      )
    end

    def revoke_invitation(actor_membership:, invitation_id:, authorization: nil)
      ManageInvitation.new.revoke(
        actor_membership: actor_membership, invitation_id: invitation_id, authorization: authorization
      )
    end

    def resend_invitation(actor_membership:, invitation_id:, authorization: nil)
      ManageInvitation.new.resend(
        actor_membership: actor_membership, invitation_id: invitation_id, authorization: authorization
      )
    end

    def create_organization(user:, name:, slug:, default_locale: "en", time_zone: "UTC", data_region: "global")
      CreateOrganization.new.call(
        user: user,
        name: name,
        slug: slug,
        default_locale: default_locale,
        time_zone: time_zone,
        data_region: data_region
      )
    end

    def resolve_organization_context(user:, selector:)
      ResolveOrganizationContext.new.call(user: user, selector: selector)
    end

    def organization_switcher(user:)
      OrganizationsForUser.new.call(user: user)
    end

    def organization_navigation(user:)
      OrganizationNavigation.new.call(user: user)
    end

    def authorize_organization_owner!(membership:)
      AuthorizeOrganizationOwner.new.call(membership: membership)
    end

    def create_membership(actor_membership:, user:, status: "active", clock: -> { Time.current }, authorization: nil)
      CreateMembership.new(clock: clock).call(
        actor_membership: actor_membership, user: user, status: status, authorization: authorization
      )
    end

    def change_membership_status(actor_membership:, target_membership_id:, operation:, clock: -> { Time.current },
      authorization: nil)
      ChangeMembershipStatus.new(clock: clock).call(
        actor_membership: actor_membership,
        target_membership_id: target_membership_id,
        operation: operation,
        authorization: authorization
      )
    end

    def membership_page(actor_membership:, page: nil, authorization: nil)
      MembershipDirectory.new.page(
        actor_membership: actor_membership, number: page, authorization: authorization
      )
    end

    def membership_detail(actor_membership:, membership_id:, authorization: nil)
      MembershipDirectory.new.find(
        actor_membership: actor_membership, membership_id: membership_id, authorization: authorization
      )
    end

    def create_team(actor_membership:, name:, authorization: nil)
      ManageTeam.new.create(actor_membership: actor_membership, name: name, authorization: authorization)
    end

    def rename_team(actor_membership:, team_id:, name:, authorization: nil)
      ManageTeam.new.rename(
        actor_membership: actor_membership, team_id: team_id, name: name, authorization: authorization
      )
    end

    def archive_team(actor_membership:, team_id:, clock: -> { Time.current }, authorization: nil)
      ManageTeam.new(clock: clock).archive(
        actor_membership: actor_membership, team_id: team_id, authorization: authorization
      )
    end

    def add_team_member(actor_membership:, team_id:, membership_id:, clock: -> { Time.current }, authorization: nil)
      ManageTeamMembership.new(clock: clock).add(
        actor_membership: actor_membership, team_id: team_id, membership_id: membership_id,
        authorization: authorization
      )
    end

    def remove_team_member(actor_membership:, team_id:, membership_id:, clock: -> { Time.current }, authorization: nil)
      ManageTeamMembership.new(clock: clock).remove(
        actor_membership: actor_membership, team_id: team_id, membership_id: membership_id,
        authorization: authorization
      )
    end

    def authorization_principals(organization_id:, membership_id:)
      ResolveAuthorizationPrincipals.new.call(organization_id: organization_id, membership_id: membership_id)
    end

    def authorization_organization(organization_id:)
      ResolveAuthorizationSubject.new.organization(organization_id: organization_id)
    end

    def authorization_membership(organization_id:, membership_id:)
      ResolveAuthorizationSubject.new.membership(
        organization_id: organization_id, membership_id: membership_id
      )
    end

    def authorization_team(organization_id:, team_id:)
      ResolveAuthorizationSubject.new.team(organization_id: organization_id, team_id: team_id)
    end

    def team_page(actor_membership:, page: nil, authorization: nil)
      TeamDirectory.new.page(actor_membership: actor_membership, number: page, authorization: authorization)
    end

    def team_details(actor_membership:, team_id:, member_page: nil, query: nil, authorization: nil)
      TeamDirectory.new.details(
        actor_membership: actor_membership,
        team_id: team_id,
        member_page: member_page,
        query: query,
        authorization: authorization
      )
    end

    def update_organization(actor_membership:, name:, slug:, default_locale: nil, time_zone: nil, authorization: nil)
      UpdateOrganization.new.call(
        actor_membership: actor_membership,
        name: name,
        slug: slug,
        default_locale: default_locale,
        time_zone: time_zone,
        authorization: authorization
      )
    end

    def transition_organization(actor_membership:, to:, clock: -> { Time.current })
      TransitionOrganization.new(clock: clock).call(actor_membership: actor_membership, to: to)
    end

    def ownership_transfer_candidates(actor_membership:, authorization:)
      OwnershipTransferCandidates.new.call(
        actor_membership: actor_membership,
        authorization: authorization
      )
    end

    def transfer_ownership(**attributes)
      TransferOwnership.new.call(**attributes)
    end

    def verify_owner_invariant!(organization_id:)
      OwnerInvariant.new.lock!(organization_id: organization_id)
    end

    def ownership_consistency_issues
      OwnershipConsistency.new.call
    end

    def with_organization_context(user_id:, organization_id:)
      user = Identity::Public.find_user!(id: user_id)
      context = resolve_organization_context(user: user, selector: organization_id)
      Current.set(
        user: user,
        organization: context.organization,
        membership: context.membership
      ) { yield context }
    ensure
      Current.reset
    end
  end
end
