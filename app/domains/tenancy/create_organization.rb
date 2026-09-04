# frozen_string_literal: true

module Tenancy
  class CreateOrganization
    Result = Data.define(:organization, :membership, :ownership)

    def initialize(clock: -> { Time.current }, ownership_model: OrganizationOwnership)
      @clock = clock
      @ownership_model = ownership_model
    end

    def call(user:, name:, slug:, default_locale: "en", time_zone: "UTC", data_region: "global")
      raise ArgumentError, "active identity user is required" unless Identity::Public.active_user?(user)

      result = Organization.transaction do
        OrganizationSlugPolicy.with_namespace_lock do
          now = @clock.call
          organization_id = SecureRandom.uuid
          membership_id = SecureRandom.uuid
          ownership_id = SecureRandom.uuid
          organization = Organization.create!(
            id: organization_id,
            name: name,
            slug: slug,
            default_locale: default_locale,
            time_zone: time_zone,
            data_region: data_region,
            status: "active",
            current_ownership_id: ownership_id
          )
          membership = Membership.create!(
            id: membership_id,
            organization: organization,
            user_id: user.id,
            status: "active",
            joined_at: now
          )
          ownership = @ownership_model.create!(
            id: ownership_id,
            organization: organization,
            membership: membership,
            assigned_at: now
          )
          Result.new(organization: organization, membership: membership, ownership: ownership)
        end
      end
      Audit.emit("organization.created", outcome: "succeeded", operation: "create")
      result
    rescue StandardError => error
      Audit.emit(
        "organization.create_rejected",
        outcome: "denied",
        operation: "create",
        reason_code: error.respond_to?(:reason_code) ? error.reason_code : nil
      )
      raise
    end
  end
end
