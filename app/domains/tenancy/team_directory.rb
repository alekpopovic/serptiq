# frozen_string_literal: true

module Tenancy
  class TeamDirectory
    PER_PAGE = 25
    CANDIDATE_LIMIT = 20

    def page(actor_membership:, number:, authorization: nil)
      organization = AuthorizeMembershipAccess.new.call(
        membership: actor_membership, permission_key: "teams.read", authorization: authorization
      )
      page = normalize_page(number)
      relation = Team.where(organization_id: organization.id).order(:name, :id)
      teams = relation.offset((page - 1) * PER_PAGE).limit(PER_PAGE)
      counts = TeamMembership.where(team_id: teams.map(&:id), removed_at: nil).group(:team_id).count
      TeamPage.new(
        entries: teams.map { |team| summarize(team, counts.fetch(team.id, 0)) },
        page: page,
        per_page: PER_PAGE,
        total_count: relation.count
      )
    end

    def details(actor_membership:, team_id:, member_page:, query:, authorization: nil)
      organization = AuthorizeMembershipAccess.new.call(
        membership: actor_membership, permission_key: "teams.read", authorization: authorization
      )
      team = Team.find_by!(id: team_id, organization_id: organization.id)
      page = normalize_page(member_page)
      relation = TeamMembership.includes(:membership)
        .where(team_id: team.id, removed_at: nil)
        .order(:added_at, :id)
      rows = relation.offset((page - 1) * PER_PAGE).limit(PER_PAGE)
      members = rows.map do |row|
        TeamMemberSummary.new(
          id: row.membership.id,
          display_name: row.membership.display_name,
          status: row.membership.status,
          effective: row.active? && team.active? && row.membership.active?
        )
      end
      total = relation.count
      previous_page = page - 1 if page > 1
      next_page = page + 1 if page * PER_PAGE < total
      TeamDetails.new(
        team: summarize(team, total),
        members: members,
        candidates: candidates(organization.id, team.id, query),
        member_page: page,
        previous_member_page: previous_page,
        next_member_page: next_page
      )
    rescue ActiveRecord::RecordNotFound
      raise OrganizationAccessDenied, cause: nil
    end

    private

    def candidates(organization_id, team_id, query)
      term = query.to_s.strip.first(80)
      relation = Membership.where(organization_id: organization_id, status: "active")
        .where.not(id: TeamMembership.where(team_id: team_id, removed_at: nil).select(:membership_id))
        .order(:display_name, :id)
      if term.present?
        escaped = ActiveRecord::Base.sanitize_sql_like(term)
        relation = relation.where("display_name ILIKE ?", "%#{escaped}%")
      end
      relation.limit(CANDIDATE_LIMIT).map do |membership|
        TeamMemberSummary.new(
          id: membership.id,
          display_name: membership.display_name,
          status: membership.status,
          effective: true
        )
      end
    end

    def normalize_page(value)
      Integer(value || 1).clamp(1, 10_000)
    rescue ArgumentError, TypeError
      1
    end

    def summarize(team, member_count)
      TeamSummary.new(
        id: team.id,
        name: team.name,
        status: team.status,
        archived_at: team.archived_at,
        member_count: member_count
      )
    end
  end
end
