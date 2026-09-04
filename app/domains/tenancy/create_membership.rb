# frozen_string_literal: true

module Tenancy
  class CreateMembership
    INITIAL_STATUSES = %w[invited active].freeze

    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(actor_membership:, user:, status: "active")
      raise ArgumentError, "active identity user is required" unless Identity::Public.active_user?(user)
      raise ArgumentError, "unsupported initial membership status" unless INITIAL_STATUSES.include?(status.to_s)

      membership = Membership.transaction do
        organization = Organization.lock.find(actor_membership&.organization_id)
        AuthorizeOrganizationOwner.new.call(membership: actor_membership)
        raise MembershipAlreadyExists if Membership.exists?(organization_id: organization.id, user_id: user.id)

        now = @clock.call
        Membership.create!(
          organization: organization,
          user_id: user.id,
          display_name: safe_display_name(user),
          status: status,
          accepted_at: status == "active" ? now : nil
        )
      end
      emit("membership.created", "create_#{status}", actor_membership, membership)
      membership
    rescue ActiveRecord::RecordNotUnique
      error = MembershipAlreadyExists.new
      emit_rejection("create_#{status}", actor_membership, nil, error)
      raise error, cause: nil
    rescue StandardError => error
      emit_rejection("create_#{status}", actor_membership, nil, error)
      raise
    end

    private

    def safe_display_name(user)
      user.display_name.to_s.strip.presence || "Member"
    end

    def emit(event_name, operation, actor, target)
      Audit.emit(
        event_name,
        outcome: "succeeded",
        operation: operation,
        actor_membership_id: actor.id,
        subject_membership_id: target.id
      )
    end

    def emit_rejection(operation, actor, target, error)
      Audit.emit(
        "membership.create_rejected",
        outcome: "denied",
        operation: operation,
        reason_code: error.respond_to?(:reason_code) ? error.reason_code : nil,
        actor_membership_id: actor&.id,
        subject_membership_id: target&.id
      )
    end
  end
end
