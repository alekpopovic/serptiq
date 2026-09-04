# frozen_string_literal: true

module Tenancy
  class UpdateOrganization
    def call(actor_membership:, name:, slug:, default_locale: nil, time_zone: nil)
      organization, old_slug = Organization.transaction do
        OrganizationSlugPolicy.with_namespace_lock do
          locked = lock_owned_organization(actor_membership)
          previous_slug = locked.slug
          attributes = { name: name, slug: slug }
          attributes[:default_locale] = default_locale unless default_locale.nil?
          attributes[:time_zone] = time_zone unless time_zone.nil?
          locked.update!(attributes)
          preserve_slug_alias!(locked, previous_slug) if locked.slug != previous_slug
          [ locked, previous_slug ]
        end
      end
      operation = old_slug == organization.slug ? "rename" : "rename_and_change_slug"
      Audit.emit("organization.renamed", outcome: "succeeded", operation: operation)
      organization
    rescue StandardError => error
      Audit.emit(
        "organization.rename_rejected",
        outcome: "denied",
        operation: "rename",
        reason_code: error.respond_to?(:reason_code) ? error.reason_code : nil
      )
      raise
    end

    private

    def preserve_slug_alias!(organization, previous_slug)
      organization.slug_aliases.where(slug: organization.slug).delete_all
      organization.slug_aliases.create!(slug: previous_slug)
    end

    def lock_owned_organization(membership)
      organization = AuthorizeOrganizationOwner.new.call(membership: membership)
      Organization.lock.find(organization.id)
    end
  end
end
