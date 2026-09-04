# frozen_string_literal: true

module Verification
  class ChallengesController < ApplicationController
    include Identity::LoginRequired
    include Tenancy::CurrentOrganization

    layout "authenticated"

    before_action :establish_current_organization!
    before_action :load_project!
    before_action :load_property!
    before_action :load_environment!

    permission_required "properties.verify", only: %i[show create attempt revoke],
      scope: -> { { project: @project, property: @property } }

    def show
      load_challenge
    end

    def create
      issued = Public.issue_challenge(
        actor_membership: Current.membership,
        project_id: @project.id,
        property_id: @property.id,
        environment_id: @environment.id,
        method: challenge_params.fetch(:method)
      )
      redirect_to verification_path(challenge_id: issued.challenge.id),
        notice: "Verification challenge issued.", status: :see_other
    rescue KeyError, ArgumentError => error
      @form_error = error.message
      load_challenge
      render :show, status: :unprocessable_content
    end

    def attempt
      result = Public.attempt_challenge(
        actor_membership: Current.membership,
        project_id: @project.id,
        property_id: @property.id,
        environment_id: @environment.id,
        challenge_id: params[:challenge_id]
      )
      notice = case result.challenge.state
      when "verified" then "Ownership verified. This remains an observed, expiring proof of control."
      when "expired" then "The challenge expired. Issue a new challenge to continue."
      when "failed" then "Verification failed after the allowed attempts. Issue a new challenge."
      else
        failure_category = result.challenge.attempts.order(sequence: :desc).pick(:failure_category)
        result.challenge.method == "dns_txt" ? DnsFailureMessage.for(failure_category) :
          "Proof was not observed yet. Check the instructions before retrying."
      end
      redirect_to verification_path(challenge_id: result.challenge.id), notice: notice, status: :see_other
    end

    def revoke
      result = Public.revoke_challenge(
        actor_membership: Current.membership,
        project_id: @project.id,
        property_id: @property.id,
        environment_id: @environment.id,
        challenge_id: params[:challenge_id]
      )
      redirect_to verification_path(challenge_id: result.challenge.id),
        notice: "Verification revoked.", status: :see_other
    end

    private

    def load_project!
      @project = Projects::Project.find_by(
        organization_id: Current.organization.id,
        slug: params[:project_slug]
      )
      raise AccessDenied unless @project
    end

    def load_property!
      @property = Properties::Property.find_by(
        organization_id: Current.organization.id,
        project_id: @project.id,
        id: params[:property_id]
      )
      raise AccessDenied unless @property&.kind.in?(%w[website web_application])
    end

    def load_environment!
      @environment = Properties::Environment.find_by(
        organization_id: Current.organization.id,
        project_id: @project.id,
        property_id: @property.id,
        id: params[:environment_id]
      )
      raise AccessDenied unless @environment
    end

    def load_challenge
      @challenge_summary = Public.challenge_details(
        actor_membership: Current.membership,
        project_id: @project.id,
        property_id: @property.id,
        environment_id: @environment.id,
        challenge_id: params[:challenge_id]
      )
      @verification_methods = MethodCatalog::LABELS.to_a
    end

    def challenge_params
      params.expect(verification: [ :method ])
    end

    def verification_path(challenge_id: nil)
      organization_project_property_environment_verification_path(
        Current.organization.slug,
        @project.slug,
        @property.id,
        @environment.id,
        challenge_id: challenge_id
      )
    end
  end
end
