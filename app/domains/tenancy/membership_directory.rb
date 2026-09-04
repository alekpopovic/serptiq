# frozen_string_literal: true

module Tenancy
  class MembershipDirectory
    PER_PAGE = 25
    MAX_PAGE = 10_000

    def page(actor_membership:, number:, authorization: nil)
      organization = AuthorizeMembershipAccess.new.call(
        membership: actor_membership, permission_key: "members.read", authorization: authorization
      )
      page_number = normalize_page(number)
      relation = Membership.where(organization_id: organization.id).order(:display_name, :id)
      entries = relation.offset((page_number - 1) * PER_PAGE).limit(PER_PAGE).map do |membership|
        summarize(membership, organization)
      end
      MembershipPage.new(
        entries: entries,
        page: page_number,
        per_page: PER_PAGE,
        total_count: relation.count
      )
    end

    def find(actor_membership:, membership_id:, authorization: nil)
      organization = AuthorizeMembershipAccess.new.call(
        membership: actor_membership, permission_key: "members.read", authorization: authorization
      )
      membership = Membership.find_by!(id: membership_id, organization_id: organization.id)
      summarize(membership, organization)
    rescue ActiveRecord::RecordNotFound
      raise OrganizationAccessDenied, cause: nil
    end

    private

    def normalize_page(value)
      Integer(value || 1).clamp(1, MAX_PAGE)
    rescue ArgumentError, TypeError
      1
    end

    def summarize(membership, organization)
      MembershipSummary.new(
        id: membership.id,
        display_name: membership.display_name,
        status: membership.status,
        accepted_at: membership.accepted_at,
        suspended_at: membership.suspended_at,
        removed_at: membership.removed_at,
        owner: organization.current_ownership.membership_id == membership.id
      )
    end
  end
end
