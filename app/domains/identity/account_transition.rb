# frozen_string_literal: true

require "digest"

module Identity
  class AccountTransition
    LOCK_NAMESPACE = "searchops:identity:account:v1"

    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(normalized_identity:, link_session: nil)
      raise ArgumentError, "provider identity is required" unless normalized_identity.is_a?(NormalizedIdentity)

      ProviderIdentity.transaction do
        now = @clock.call
        locked_session = lock_and_validate_session(link_session, now)
        advisory_lock("#{normalized_identity.provider}:subject:#{normalized_identity.subject}")
        stored = ProviderIdentity.lock.find_by(
          provider: normalized_identity.provider,
          provider_subject: normalized_identity.subject
        )

        if locked_session
          link_identity(stored, normalized_identity, locked_session.user, now)
        else
          sign_in_identity(stored, normalized_identity, now)
        end
      end
    end

    private

    def lock_and_validate_session(session, now)
      return unless session

      locked = Session.lock.includes(:user).find(session.id)
      active = locked.status_at(now) == :active && locked.user.active?
      recent = locked.authenticated_at >= now - SessionPolicy::RECENT_AUTHENTICATION_WINDOW
      raise InvalidAccountLink.new(reason_code: "account_link_session_invalid") unless active && recent

      locked
    rescue ActiveRecord::RecordNotFound
      raise InvalidAccountLink.new(reason_code: "account_link_session_invalid"), cause: nil
    end

    def link_identity(stored, observed, user, now)
      if stored && stored.user_id != user.id
        raise InvalidAccountLink.new(reason_code: "provider_identity_owned_by_another_user")
      end

      advisory_lock("#{user.id}:provider:#{observed.provider}")
      another_active = ProviderIdentity.where(
        user_id: user.id,
        provider: observed.provider,
        revoked_at: nil
      ).where.not(id: stored&.id).exists?
      raise InvalidAccountLink.new(reason_code: "provider_already_linked") if another_active

      record = stored || ProviderIdentity.new(
        user: user,
        provider: observed.provider,
        provider_subject: observed.subject
      )
      persist_observation(record, observed, now)
      Audit.emit(
        "auth.identity_linked",
        outcome: "succeeded",
        operation: "link",
        provider: record.provider,
        actor_user_id: user.id,
        target_type: "Identity",
        target_id: record.id
      )
      user
    end

    def sign_in_identity(stored, observed, now)
      if stored
        raise RevokedProviderIdentity unless stored.active? && stored.user.active?

        persist_observation(stored, observed, now)
        return stored.user
      end

      advisory_lock("email:#{observed.email}") if observed.email_verified?
      raise AccountLinkRequired if observed.email_verified? && email_collision?(observed.email)

      user = User.create!(
        primary_email: observed.email_verified? ? observed.email : nil,
        display_name: observed.profile["name"] || observed.profile["login"],
        avatar_url: observed.profile["avatar_url"],
        locale: observed.profile["locale"].presence || "en"
      )
      persist_observation(
        ProviderIdentity.new(
          user: user,
          provider: observed.provider,
          provider_subject: observed.subject
        ),
        observed,
        now
      )
      user
    end

    def persist_observation(record, observed, now)
      record.update!(
        email: observed.email,
        email_verified: observed.email_verified?,
        profile: observed.profile,
        last_authenticated_at: now,
        revoked_at: nil
      )
    end

    def email_collision?(email)
      ProviderIdentity.where(email: email).exists? || User.where(primary_email: email, deleted_at: nil).exists?
    end

    def advisory_lock(material)
      digest = Digest::SHA256.digest("#{LOCK_NAMESPACE}:#{material}")
      key = digest.unpack1("q>")
      bind = ActiveRecord::Relation::QueryAttribute.new(
        "advisory_lock_key",
        key,
        ActiveRecord::Type::Integer.new(limit: 8)
      )
      ActiveRecord::Base.connection.exec_query(
        "SELECT pg_advisory_xact_lock($1::bigint)::text AS locked",
        "Provider account advisory lock",
        [ bind ]
      )
    end
  end
end
