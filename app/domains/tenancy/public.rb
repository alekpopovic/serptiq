# frozen_string_literal: true

module Tenancy
  module Public
    module_function

    def first_run_status(user:)
      raise ArgumentError, "active identity user is required" unless Identity::Public.active_user?(user)

      kind = OrganizationNavigation.new.call(user: user).any? ? :returning : :no_organization
      FirstRunStatus.new(kind: kind)
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

    def update_organization(actor_membership:, name:, slug:, default_locale: nil, time_zone: nil)
      UpdateOrganization.new.call(
        actor_membership: actor_membership,
        name: name,
        slug: slug,
        default_locale: default_locale,
        time_zone: time_zone
      )
    end

    def transition_organization(actor_membership:, to:, clock: -> { Time.current })
      TransitionOrganization.new(clock: clock).call(actor_membership: actor_membership, to: to)
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
