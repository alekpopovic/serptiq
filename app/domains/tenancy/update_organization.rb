# frozen_string_literal: true

module Tenancy
  class UpdateOrganization
    def call(actor_membership:, name:, slug:)
      organization, old_slug = Organization.transaction do
        locked = lock_owned_organization(actor_membership)
        previous_slug = locked.slug
        locked.update!(name: name, slug: slug)
        [ locked, previous_slug ]
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

    def lock_owned_organization(membership)
      raise OrganizationAccessDenied unless membership.is_a?(Membership) && membership.active?

      organization = Organization.lock.find(membership.organization_id)
      owned = organization.active? && OrganizationOwnership.where(
        organization_id: organization.id,
        membership_id: membership.id,
        ended_at: nil
      ).exists?
      raise OrganizationAccessDenied unless owned

      organization
    rescue ActiveRecord::RecordNotFound
      raise OrganizationAccessDenied, cause: nil
    end
  end
end
