# frozen_string_literal: true

module Tenancy
  class TeamsController < ApplicationController
    include Identity::LoginRequired
    include CurrentOrganization

    layout "authenticated"

    before_action :establish_current_organization!
    before_action :redirect_alias_to_canonical_slug
    permission_required "teams.read", only: %i[index show]
    permission_required "teams.manage", only: %i[new create update archive add_member remove_member]
    permission_hint "teams.manage", only: %i[index show]

    def index
      @team_page = Public.team_page(
        actor_membership: Current.membership,
        authorization: authorization_decision!("teams.read"),
        page: params[:page]
      )
    end

    def new
      @team = Team.new
    end

    def create
      team = Public.create_team(
        actor_membership: Current.membership,
        authorization: authorization_decision!("teams.manage"),
        name: team_params[:name]
      )
      redirect_to organization_team_path(Current.organization.slug, team.id),
        notice: "Team created.", status: :see_other
    rescue ActiveRecord::RecordInvalid => error
      @team = error.record
      render :new, status: :unprocessable_content
    end

    def show
      prepare_details
    end

    def update
      team = Public.rename_team(
        actor_membership: Current.membership,
        authorization: authorization_decision!("teams.manage"),
        team_id: params[:id],
        name: team_params[:name]
      )
      redirect_to organization_team_path(Current.organization.slug, team.id),
        notice: "Team renamed.", status: :see_other
    rescue ActiveRecord::RecordInvalid => error
      @team = error.record
      prepare_details
      render :show, status: :unprocessable_content
    end

    def archive
      Public.archive_team(
        actor_membership: Current.membership,
        authorization: authorization_decision!("teams.manage"),
        team_id: params[:id]
      )
      redirect_to organization_team_path(Current.organization.slug, params[:id]),
        notice: "Team archived. Its future role grants are inactive.", status: :see_other
    end

    def add_member
      Public.add_team_member(
        actor_membership: Current.membership,
        authorization: authorization_decision!("teams.manage"),
        team_id: params[:id],
        membership_id: params.expect(:membership_id)
      )
      redirect_to organization_team_path(Current.organization.slug, params[:id]),
        notice: "Member added to team.", status: :see_other
    end

    def remove_member
      Public.remove_team_member(
        actor_membership: Current.membership,
        authorization: authorization_decision!("teams.manage"),
        team_id: params[:id],
        membership_id: params[:membership_id]
      )
      redirect_to organization_team_path(Current.organization.slug, params[:id]),
        notice: "Member removed from team.", status: :see_other
    end

    private

    def prepare_details
      @details = Public.team_details(
        actor_membership: Current.membership,
        authorization: authorization_decision!("teams.read"),
        team_id: params[:id],
        member_page: params[:member_page],
        query: params[:q]
      )
      @team ||= Team.find(@details.team.id)
    end

    def team_params
      params.expect(team: [ :name ])
    end

    def redirect_alias_to_canonical_slug
      return if organization_slug_is_canonical?

      destination = if action_name.in?(%w[index new create])
        organization_teams_path(Current.organization.slug)
      else
        organization_team_path(Current.organization.slug, params[:id])
      end
      redirect_to destination, status: :moved_permanently
    end
  end
end
