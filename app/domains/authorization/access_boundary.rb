# frozen_string_literal: true

require "digest"

module Authorization
  class AccessBoundary
    def initialize(authorization: nil, entitlement_resolver: nil, quota_reserver: nil,
      quota_releaser: nil, instrumentation: AccessInstrumentation.new)
      @authorization = authorization || ->(request) { Decision.new.call(request, validate_resource: false) }
      @entitlement_resolver = entitlement_resolver || ->(**attributes) { Entitlements::Public.resolve(**attributes) }
      @quota_reserver = quota_reserver || ->(**attributes) { Usage::Public.reserve(**attributes) }
      @quota_releaser = quota_releaser || ->(**attributes) { Usage::Public.release_reservation(**attributes) }
      @instrumentation = instrumentation
    end

    def call(request)
      validate_request!(request)
      authorization = @authorization.call(request)
      return emit(authorization_denial(request, authorization), request) if authorization.deny?

      entitlement = resolve_entitlement(request)
      if entitlement && !entitlement.enabled?
        return emit(entitlement_denial(authorization, entitlement), request)
      end

      resource_reason = resource_denial_reason(request)
      if resource_reason
        return emit(resource_denial(request, authorization, entitlement, resource_reason), request)
      end

      reservation = reserve_quota(request)
      emit(allowed(authorization, entitlement, reservation), request)
    rescue Usage::Public::QuotaExceeded => error
      emit(quota_denial(authorization, entitlement, error.denial), request)
    end

    def authorize!(request)
      decision = call(request)
      raise_denial!(decision) if decision.deny?

      decision
    end

    def with_access(request)
      decision = authorize!(request)
      return yield(decision) unless decision.reserved?

      begin
        yield decision
      rescue StandardError
        release_after_failure(request, decision.reservation)
        raise
      end
    end

    private

    def validate_request!(request)
      raise ArgumentError, "Authorization::AccessRequest is required" unless request.is_a?(AccessRequest)
    end

    def resolve_entitlement(request)
      return unless request.entitlement?

      @entitlement_resolver.call(
        organization_id: request.organization_id,
        entitlement_key: request.entitlement_key,
        at: request.evaluated_at || Time.current
      )
    end

    def resource_denial_reason(request)
      resource = request.resource
      return unless resource
      return "scope_mismatch" unless resource.organization_id == request.organization_id &&
        resource.scope_type == request.scope_type && resource.scope_id == request.scope_id
      "resource_unavailable" unless resource.available?
    end

    def reserve_quota(request)
      return unless request.metered?

      @quota_reserver.call(
        window: request.usage_window,
        idempotency_key: request.idempotency_key,
        quantity: request.metered_quantity,
        source: request.usage_source,
        expires_at: request.reservation_expires_at,
        at: request.evaluated_at
      )
    end

    def authorization_denial(request, authorization)
      public_code = authorization.reason_code == "not_authenticated" ?
        "authentication_required" : "authorization_denied"
      denied(
        stage: "authorization", reason_code: authorization.reason_code,
        public_error_code: public_code, authorization: authorization,
        provenance: { authorization: authorization.sources, operation: request.permission_key }
      )
    end

    def entitlement_denial(authorization, entitlement)
      denied(
        stage: "entitlement", reason_code: entitlement.reason_code,
        public_error_code: "entitlement_required", authorization: authorization,
        entitlement: entitlement,
        provenance: authorization_provenance(authorization).merge(entitlement: entitlement.provenance)
      )
    end

    def resource_denial(_request, authorization, entitlement, reason_code)
      public_code = reason_code == "scope_mismatch" ? "authorization_denied" : "resource_conflict"
      denied(
        stage: "resource", reason_code: reason_code, public_error_code: public_code,
        authorization: authorization, entitlement: entitlement,
        provenance: authorization_provenance(authorization).merge(
          entitlement: entitlement&.provenance, resource: "caller_validated_state"
        ).compact
      )
    end

    def quota_denial(authorization, entitlement, denial)
      denied(
        stage: "quota", reason_code: denial.reason_code, public_error_code: "quota_exceeded",
        authorization: authorization, entitlement: entitlement, quota_denial: denial,
        provenance: authorization_provenance(authorization).merge(
          entitlement: entitlement&.provenance, quota: "atomic_usage_reservation"
        ).compact
      )
    end

    def allowed(authorization, entitlement, reservation)
      AccessDecision.new(
        allowed: true, stage: "allowed", reason_code: "access_granted",
        authorization: authorization, entitlement: entitlement, reservation: reservation,
        provenance: authorization_provenance(authorization).merge(
          entitlement: entitlement&.provenance,
          quota: reservation ? "atomic_usage_reservation" : nil
        ).compact
      )
    end

    def denied(**attributes)
      AccessDecision.new(allowed: false, **attributes)
    end

    def authorization_provenance(authorization)
      { authorization: authorization.sources }
    end

    def emit(decision, request)
      @instrumentation.emit(decision, request: request)
      decision
    end

    def raise_denial!(decision)
      case decision.public_error_code
      when "authentication_required"
        raise AuthenticationRequired.new(access_decision: decision)
      when "authorization_denied"
        raise AccessDenied.new(decision: denial_authorization(decision))
      when "entitlement_required"
        raise Entitlements::Public::Required.new(access_decision: decision)
      when "resource_conflict"
        raise ResourceUnavailable.new(access_decision: decision)
      when "quota_exceeded"
        raise Usage::Public::QuotaExceeded.new(denial: decision.quota_denial)
      else
        raise "unsupported access denial"
      end
    end

    def denial_authorization(decision)
      return decision.authorization if decision.stage == "authorization"

      original = decision.authorization
      DecisionResult.new(
        allowed: false, reason_code: decision.reason_code,
        permission_key: original.permission_key, actor_membership_id: original.actor_membership_id,
        organization_id: original.organization_id, scope_type: original.scope_type,
        scope_id: original.scope_id
      )
    end

    def release_after_failure(request, reservation)
      @quota_releaser.call(
        organization_id: request.organization_id,
        reservation_id: reservation.id,
        idempotency_key: "access-release-#{Digest::SHA256.hexdigest(request.idempotency_key)}",
        at: request.evaluated_at
      )
    rescue StandardError => error
      Shared::Public.report_observability_failure(error, event_name: "access.quota_release_failed")
    end
  end
end
