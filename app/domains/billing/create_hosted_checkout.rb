# frozen_string_literal: true

require "openssl"

module Billing
  class CreateHostedCheckout
    INITIAL_TTL = 30.minutes
    UNCERTAIN_PROVIDER_CATEGORIES = %w[timeout unavailable].freeze

    def self.from_settings(auditor:, settings: Rails.application.config.x.searchops,
      registry: ProviderRegistry.new(settings: settings))
      provider_key = settings.fetch(:billing_provider).to_s
      raise ProviderUnknown.new(reason_code: "billing_provider_disabled") if provider_key == "disabled"

      new(
        provider: registry.fetch(provider_key),
        environment: Rails.env.to_s,
        application_origin: settings.fetch(:application_origin),
        auditor: auditor
      )
    end

    def initialize(provider:, environment:, application_origin:, clock: -> { Time.current },
      correlation: CheckoutCorrelation.new, digest_secret: Rails.application.secret_key_base,
      auditor:)
      @provider = provider
      @environment = ValueNormalization.string!(environment, name: "environment", maximum: 16)
      raise ArgumentError, "billing environment is invalid" unless CustomerMapping::ENVIRONMENTS.include?(@environment)

      @url_policy = HostedUrlPolicy.new(application_origin: application_origin)
      @clock = clock
      @correlation = correlation
      @digest_secret = ValueNormalization.string!(digest_secret, name: "idempotency secret", maximum: 4096)
      raise ArgumentError, "billing auditor is invalid" unless auditor.respond_to?(:record!)

      @auditor = auditor
    end

    def call(actor_membership:, organization:, plan_version_id:, currency:, billing_interval:,
      success_path:, cancel_path:, request_key:, authorization:)
      organization = AuthorizeManagement.new.call(
        actor_membership: actor_membership,
        organization: organization,
        authorization: authorization
      )
      now = @clock.call
      target = target_version!(plan_version_id, currency, billing_interval, now)
      reject_unchanged_plan!(organization, target)
      mapping = Billing::Public.plan_mapping(
        plan_version_id: target.id,
        provider: @provider.provider_key,
        environment: @environment,
        currency: currency,
        billing_interval: billing_interval
      )
      session = reserve_session!(
        actor_membership: actor_membership,
        organization: organization,
        target: target,
        mapping: mapping,
        request_key: request_key,
        now: now
      )
      external_mutation_started = false

      customer = existing_customer(organization)
      unless customer
        external_mutation_started = true
        customer = create_customer!(actor_membership, organization, session)
      end
      attach_customer!(session, customer)

      checkout_request = CheckoutRequest.new(
        organization_id: organization.id,
        plan_version_id: target.id,
        variant_reference: mapping.variant_reference,
        customer_reference: customer.reference,
        email: actor_membership.user.primary_email,
        success_url: @url_policy.call(success_path),
        cancel_url: @url_policy.call(cancel_path),
        idempotency_key: "checkout:#{session.id}",
        metadata: correlation_metadata(session)
      )
      external_mutation_started = true
      result = @provider.create_checkout(request: checkout_request)
      validate_checkout_result!(result, now)
      complete_session!(session, result, target, actor_membership, now)
      result
    rescue StandardError => error
      record_failure(session, error, external_mutation_started) if session
      raise
    end

    private

    def target_version!(plan_version_id, currency, interval, at)
      Plans::Public.exact_purchasable_version(
        id: plan_version_id,
        currency: currency,
        billing_interval: interval,
        at: at
      )
    end

    def reject_unchanged_plan!(organization, target)
      current = Billing::Public.active_subscription(organization_id: organization.id)
      return unless current&.plan_version_id == target.id

      raise CheckoutConflict.new(reason_code: "billing_checkout_target_unchanged")
    end

    def reserve_session!(actor_membership:, organization:, target:, mapping:, request_key:, now:)
      request_digest = idempotency_digest(request_key)
      CheckoutSession.active.where(organization_id: organization.id, expires_at: ..now).update_all(
        state: "expired", updated_at: now
      )
      CheckoutSession.create!(
        organization_id: organization.id,
        plan_version_id: target.id,
        actor_membership_id: actor_membership.id,
        provider: mapping.provider,
        environment: mapping.environment,
        currency: mapping.currency,
        billing_interval: mapping.billing_interval,
        state: "preparing",
        idempotency_digest: request_digest,
        expires_at: now + INITIAL_TTL,
        created_at: now,
        updated_at: now
      )
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => error
      reason = if CheckoutSession.active.exists?(organization_id: organization.id)
        "billing_checkout_already_active"
      elsif CheckoutSession.exists?(organization_id: organization.id, idempotency_digest: request_digest)
        "billing_checkout_request_replayed"
      else
        raise error
      end
      raise CheckoutConflict.new(reason_code: reason), cause: nil
    end

    def existing_customer(organization)
      Billing::Public.customer_mapping(
        organization_id: organization.id,
        provider: @provider.provider_key,
        environment: @environment
      )
    rescue ProviderMappingMissing => error
      raise unless error.reason_code == "billing_customer_mapping_missing"

      nil
    end

    def create_customer!(actor_membership, organization, session)
      email = actor_membership.user.primary_email
      unless email.present?
        raise Shared::Public::ValidationError.new(reason_code: "billing_customer_email_required")
      end

      created = @provider.create_customer(request: CustomerRequest.new(
        organization_id: organization.id,
        name: organization.name,
        email: email,
        idempotency_key: "customer:#{session.id}"
      ))
      unless created.provider == @provider.provider_key && created.organization_id == organization.id
        raise ProviderFailure.new(
          provider: @provider.provider_key,
          operation: "create_customer",
          category: "malformed_response",
          retryable: false
        )
      end

      Billing::Public.register_customer_mapping(
        organization_id: organization.id,
        provider: @provider.provider_key,
        environment: @environment,
        provider_customer_id: created.reference
      )
    end

    def attach_customer!(session, customer)
      mapping = CustomerMapping.find_by!(
        organization_id: session.organization_id,
        provider: session.provider,
        environment: session.environment,
        provider_customer_id: customer.reference
      )
      session.update!(billing_customer_id: mapping.id)
    end

    def correlation_metadata(session)
      {
        "checkout_session_id" => session.id,
        "correlation" => @correlation.sign(
          organization_id: session.organization_id,
          plan_version_id: session.plan_version_id,
          checkout_session_id: session.id,
          environment: session.environment
        )
      }
    end

    def validate_checkout_result!(result, now)
      return if result.is_a?(CheckoutResult) && result.provider == @provider.provider_key && result.expires_at > now

      raise ProviderFailure.new(
        provider: @provider.provider_key,
        operation: "create_checkout",
        category: "malformed_response",
        retryable: false
      )
    end

    def complete_session!(session, result, target, actor_membership, now)
      CheckoutSession.transaction do
        session.lock!
        session.update!(
          state: "ready",
          provider_checkout_id: result.reference,
          expires_at: result.expires_at,
          ready_at: now
        )
        @auditor.record!(
          organization_id: session.organization_id,
          actor_membership_id: actor_membership.id,
          action: "billing.checkout_created",
          target_type: "BillingCheckout",
          target_id: session.id,
          result: "succeeded",
          metadata: {
            provider: session.provider,
            operation: "create_checkout",
            status: session.state,
            currency: session.currency,
            billing_interval: session.billing_interval,
            plan_version: target.version
          }
        )
      end
    end

    def record_failure(session, error, external_mutation_started)
      return unless session.persisted?

      session.reload
      return unless session.state == "preparing"

      uncertain = external_mutation_started && uncertain_outcome?(error)
      session.update_columns(
        state: uncertain ? "uncertain" : "failed",
        failure_category: failure_category(error),
        failed_at: @clock.call,
        updated_at: @clock.call
      )
    rescue StandardError => transition_error
      Rails.error.report(transition_error, handled: true, severity: :error,
        context: { "failed_billing_checkout_session_id" => session.id })
    end

    def uncertain_outcome?(error)
      !error.is_a?(ProviderFailure) || UNCERTAIN_PROVIDER_CATEGORIES.include?(error.category)
    end

    def failure_category(error)
      value = if error.respond_to?(:category)
        error.category
      elsif error.respond_to?(:reason_code)
        error.reason_code
      else
        "internal_failure"
      end
      value.to_s.match?(ValueNormalization::KEY_PATTERN) ? value.to_s : "internal_failure"
    end

    def idempotency_digest(request_key)
      key = ValueNormalization.string!(request_key, name: "checkout request key", maximum: 200)
      OpenSSL::HMAC.hexdigest("SHA256", @digest_secret, key)
    end
  end
end
