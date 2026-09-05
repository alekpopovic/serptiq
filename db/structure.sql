SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: enforce_billing_customer_mapping_immutability(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_billing_customer_mapping_immutability() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' OR
     NEW.organization_id IS DISTINCT FROM OLD.organization_id OR
     NEW.provider IS DISTINCT FROM OLD.provider OR
     NEW.environment IS DISTINCT FROM OLD.environment OR
     NEW.provider_customer_id IS DISTINCT FROM OLD.provider_customer_id THEN
    RAISE EXCEPTION 'billing customer mappings are immutable' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: enforce_crawl_scan_usage_operation_lifecycle(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_crawl_scan_usage_operation_lifecycle() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF resource_deletion_stage_authorized(
      OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
    ) THEN
      RETURN OLD;
    END IF;
    RAISE EXCEPTION 'scan usage operations require lifecycle deletion' USING ERRCODE = '23514';
  END IF;
  IF TG_OP = 'INSERT' THEN
    IF NEW.operation_kind <> 'artifact' AND NOT EXISTS (
      SELECT 1
      FROM usage_quota_allocations allocation
      JOIN usage_meter_definitions meter
        ON meter.id = allocation.usage_meter_definition_id
      JOIN usage_meter_rates rate ON rate.id = allocation.usage_meter_rate_id
      WHERE allocation.id = NEW.usage_quota_allocation_id
        AND allocation.organization_id = NEW.organization_id
        AND allocation.source_type = 'Scan' AND allocation.source_id = NEW.scan_id
        AND allocation.state = 'held' AND meter.key = NEW.meter_key
        AND rate.version = NEW.meter_rate_version
        AND allocation.applied_weight = NEW.applied_weight
        AND allocation.billed_quantity = NEW.reserved_credits
    ) THEN
      RAISE EXCEPTION 'scan usage operation allocation is inconsistent' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
  END IF;
  IF OLD.organization_id IS DISTINCT FROM NEW.organization_id OR
    OLD.project_id IS DISTINCT FROM NEW.project_id OR OLD.property_id IS DISTINCT FROM NEW.property_id OR
    OLD.environment_id IS DISTINCT FROM NEW.environment_id OR OLD.scan_id IS DISTINCT FROM NEW.scan_id OR
    OLD.usage_quota_allocation_id IS DISTINCT FROM NEW.usage_quota_allocation_id OR
    OLD.operation_kind IS DISTINCT FROM NEW.operation_kind OR OLD.meter_key IS DISTINCT FROM NEW.meter_key OR
    OLD.meter_rate_version IS DISTINCT FROM NEW.meter_rate_version OR
    OLD.applied_weight IS DISTINCT FROM NEW.applied_weight OR
    OLD.reserved_credits IS DISTINCT FROM NEW.reserved_credits OR
    OLD.source_key_digest IS DISTINCT FROM NEW.source_key_digest OR
    OLD.request_checksum IS DISTINCT FROM NEW.request_checksum OR
    OLD.attempted_at IS DISTINCT FROM NEW.attempted_at OR OLD.created_at IS DISTINCT FROM NEW.created_at OR
    OLD.state <> 'reserved' OR NEW.state NOT IN ('billed', 'not_billable') THEN
    RAISE EXCEPTION 'scan usage operation transition is invalid' USING ERRCODE = '23514';
  END IF;
  IF NEW.state = 'billed' AND NOT EXISTS (
    SELECT 1 FROM usage_quota_allocations allocation
    WHERE allocation.id = NEW.usage_quota_allocation_id
      AND allocation.organization_id = NEW.organization_id
      AND allocation.state = 'consumed' AND allocation.usage_event_id = NEW.usage_event_id
  ) THEN
    RAISE EXCEPTION 'scan usage operation event is inconsistent' USING ERRCODE = '23514';
  END IF;
  IF NEW.state = 'not_billable' AND NEW.usage_quota_allocation_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM usage_quota_allocations allocation
    WHERE allocation.id = NEW.usage_quota_allocation_id
      AND allocation.organization_id = NEW.organization_id AND allocation.state = 'released'
  ) THEN
    RAISE EXCEPTION 'scan usage operation release is inconsistent' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: enforce_entitlement_definition_stability(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_entitlement_definition_stability() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' OR NEW IS DISTINCT FROM OLD THEN
    RAISE EXCEPTION 'entitlement definition identity is immutable' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: enforce_organization_entitlement_override_append_only(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_organization_entitlement_override_append_only() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'entitlement overrides are append-only' USING ERRCODE = '23514';
  END IF;
  IF OLD.organization_id IS DISTINCT FROM NEW.organization_id OR
     OLD.entitlement_definition_id IS DISTINCT FROM NEW.entitlement_definition_id OR
     OLD.value_type IS DISTINCT FROM NEW.value_type OR OLD.value IS DISTINCT FROM NEW.value OR
     OLD.starts_at IS DISTINCT FROM NEW.starts_at OR OLD.ends_at IS DISTINCT FROM NEW.ends_at OR
     OLD.reason IS DISTINCT FROM NEW.reason OR OLD.source IS DISTINCT FROM NEW.source OR
     OLD.created_by_membership_id IS DISTINCT FROM NEW.created_by_membership_id OR
     OLD.revoked_at IS NOT NULL OR NEW.revoked_at IS NULL OR NEW.revoked_by_membership_id IS NULL THEN
    RAISE EXCEPTION 'entitlement override history is immutable' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: enforce_plan_entitlement_immutability(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_plan_entitlement_immutability() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM plan_versions WHERE id = OLD.plan_version_id AND status <> 'draft') THEN
    RAISE EXCEPTION 'published plan entitlements are immutable' USING ERRCODE = '23514';
  END IF;
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: enforce_plan_version_immutability(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_plan_version_immutability() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF EXISTS ( SELECT 1 FROM audit_events WHERE target_type = 'PlanVersion' AND target_id = OLD.id ) THEN RAISE EXCEPTION 'audited plan versions cannot be deleted' USING ERRCODE = '23514'; END IF;
    IF OLD.status <> 'draft' THEN
      RAISE EXCEPTION 'non-draft plan versions cannot be deleted' USING ERRCODE = '23514';
    END IF;
    RETURN OLD;
  END IF;

  IF OLD.status <> 'draft' AND (
    NEW.plan_id IS DISTINCT FROM OLD.plan_id OR
    NEW.version IS DISTINCT FROM OLD.version OR
    NEW.display_name IS DISTINCT FROM OLD.display_name OR
    NEW.positioning IS DISTINCT FROM OLD.positioning OR
    NEW.currency IS DISTINCT FROM OLD.currency OR
    NEW.pricing_kind IS DISTINCT FROM OLD.pricing_kind OR
    NEW.monthly_price_cents IS DISTINCT FROM OLD.monthly_price_cents OR
    NEW.annual_price_cents IS DISTINCT FROM OLD.annual_price_cents OR
    NEW.entitlements_snapshot IS DISTINCT FROM OLD.entitlements_snapshot OR
    NEW.catalog_checksum IS DISTINCT FROM OLD.catalog_checksum OR
    NEW.effective_at IS DISTINCT FROM OLD.effective_at OR
    NEW.published_at IS DISTINCT FROM OLD.published_at
  ) THEN
    RAISE EXCEPTION 'non-draft plan version snapshots are immutable' USING ERRCODE = '23514';
  END IF;

  IF (OLD.status = 'published' AND NEW.status NOT IN ('published', 'retired', 'grandfathered')) OR
     (OLD.status = 'grandfathered' AND NEW.status NOT IN ('grandfathered', 'retired')) OR
     (OLD.status = 'retired' AND NEW.status <> OLD.status) THEN
    RAISE EXCEPTION 'invalid plan version lifecycle transition' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: enforce_property_primary_environment(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_property_primary_environment() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  target_property_id uuid;
  target_organization_id uuid;
  target_project_id uuid;
  property_row properties%ROWTYPE;
  primary_count integer;
BEGIN
  IF TG_TABLE_NAME = 'properties' THEN
    target_property_id := COALESCE(NEW.id, OLD.id);
    target_organization_id := COALESCE(NEW.organization_id, OLD.organization_id);
    target_project_id := COALESCE(NEW.project_id, OLD.project_id);
  ELSE
    target_property_id := COALESCE(NEW.property_id, OLD.property_id);
    target_organization_id := COALESCE(NEW.organization_id, OLD.organization_id);
    target_project_id := COALESCE(NEW.project_id, OLD.project_id);
  END IF;

  SELECT * INTO property_row FROM properties
  WHERE id = target_property_id
    AND organization_id = target_organization_id
    AND project_id = target_project_id;
  IF NOT FOUND OR property_row.status <> 'active'
    OR property_row.kind NOT IN ('website', 'web_application') THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  SELECT count(*) INTO primary_count FROM property_environments
  WHERE property_id = target_property_id
    AND organization_id = target_organization_id
    AND project_id = target_project_id
    AND "primary" = TRUE AND status = 'active' AND kind = 'production';
  IF primary_count <> 1 THEN
    RAISE EXCEPTION 'active website property requires exactly one primary production environment';
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;


--
-- Name: enforce_usage_catalog_immutability(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_usage_catalog_immutability() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'usage catalog rows are immutable' USING ERRCODE = '23514';
END;
$$;


--
-- Name: enforce_usage_event_integrity(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_usage_event_integrity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  original usage_events%ROWTYPE;
  corrected numeric;
  event_window usage_windows%ROWTYPE;
BEGIN
  IF TG_OP <> 'INSERT' THEN
    RAISE EXCEPTION 'usage events are append-only' USING ERRCODE = '23514';
  END IF;

  SELECT * INTO event_window FROM usage_windows WHERE id = NEW.usage_window_id;
  PERFORM lock_usage_quota_pool(NEW.usage_window_id);
  IF NEW.event_kind = 'usage' AND
    (NEW.occurred_at < event_window.starts_at OR NEW.occurred_at >= event_window.ends_at) THEN
    RAISE EXCEPTION 'usage event occurred outside its window' USING ERRCODE = '23514';
  END IF;

  IF NEW.event_kind = 'correction' THEN
    PERFORM pg_advisory_xact_lock(NEW.correction_of_event_id);
    SELECT * INTO original FROM usage_events WHERE id = NEW.correction_of_event_id;
    IF original.id IS NULL OR original.event_kind = 'correction' OR
      original.usage_meter_rate_id <> NEW.usage_meter_rate_id OR
      original.applied_weight <> NEW.applied_weight OR
      original.source_type <> NEW.source_type OR original.source_id <> NEW.source_id THEN
      RAISE EXCEPTION 'usage correction target is invalid' USING ERRCODE = '23514';
    END IF;
    SELECT original.quantity + COALESCE(sum(quantity), 0) INTO corrected
    FROM usage_events WHERE correction_of_event_id = original.id;
    corrected := corrected + NEW.quantity;
    IF (original.quantity > 0 AND (NEW.quantity >= 0 OR corrected < 0)) OR
      (original.quantity < 0 AND (NEW.quantity <= 0 OR corrected > 0)) THEN
      RAISE EXCEPTION 'usage correction overcompensates its target' USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: enforce_usage_quota_allocation_lifecycle(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_usage_quota_allocation_lifecycle() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  reservation usage_quota_reservations%ROWTYPE;
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'usage quota allocations cannot be deleted' USING ERRCODE = '23514';
  END IF;

  SELECT * INTO reservation FROM usage_quota_reservations
    WHERE id = CASE WHEN TG_OP = 'INSERT' THEN NEW.usage_quota_reservation_id ELSE OLD.usage_quota_reservation_id END;
  PERFORM lock_usage_quota_pool(reservation.usage_window_id);

  IF TG_OP = 'INSERT' THEN
    IF reservation.id IS NULL OR reservation.organization_id <> NEW.organization_id OR
      reservation.source_type <> NEW.source_type OR reservation.source_id <> NEW.source_id OR
      NOT EXISTS (
        SELECT 1
        FROM usage_windows target_window
        JOIN usage_meter_definitions target_meter
          ON target_meter.id = target_window.usage_meter_definition_id
        JOIN usage_windows anchor_window ON anchor_window.id = reservation.usage_window_id
        JOIN usage_meter_definitions anchor_meter
          ON anchor_meter.id = anchor_window.usage_meter_definition_id
        WHERE target_window.id = NEW.usage_window_id
          AND target_window.organization_id = reservation.organization_id
          AND target_window.starts_at = anchor_window.starts_at
          AND target_window.ends_at = anchor_window.ends_at
          AND target_meter.pool_key = anchor_meter.pool_key
          AND target_meter.billing_unit = anchor_meter.billing_unit
          AND target_meter.quota_entitlement_key IS NOT DISTINCT FROM anchor_meter.quota_entitlement_key
          AND target_meter.window_policy = anchor_meter.window_policy
      ) THEN
      RAISE EXCEPTION 'usage quota allocation reservation context is invalid' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
  END IF;

  IF OLD.organization_id IS DISTINCT FROM NEW.organization_id OR
    OLD.usage_quota_reservation_id IS DISTINCT FROM NEW.usage_quota_reservation_id OR
    OLD.usage_window_id IS DISTINCT FROM NEW.usage_window_id OR
    OLD.usage_meter_definition_id IS DISTINCT FROM NEW.usage_meter_definition_id OR
    OLD.usage_meter_rate_id IS DISTINCT FROM NEW.usage_meter_rate_id OR
    OLD.idempotency_key_digest IS DISTINCT FROM NEW.idempotency_key_digest OR
    OLD.request_checksum IS DISTINCT FROM NEW.request_checksum OR
    OLD.quantity IS DISTINCT FROM NEW.quantity OR OLD.applied_weight IS DISTINCT FROM NEW.applied_weight OR
    OLD.billed_quantity IS DISTINCT FROM NEW.billed_quantity OR
    OLD.source_type IS DISTINCT FROM NEW.source_type OR OLD.source_id IS DISTINCT FROM NEW.source_id OR
    OLD.allocated_at IS DISTINCT FROM NEW.allocated_at OR OLD.created_at IS DISTINCT FROM NEW.created_at OR
    OLD.state <> 'held' OR NEW.state NOT IN ('consumed', 'released') THEN
    RAISE EXCEPTION 'usage quota allocation transition is invalid' USING ERRCODE = '23514';
  END IF;

  IF NEW.state = 'consumed' AND NOT EXISTS (
    SELECT 1 FROM usage_events event
    WHERE event.id = NEW.usage_event_id AND event.organization_id = NEW.organization_id
      AND event.usage_window_id = NEW.usage_window_id
      AND event.usage_meter_definition_id = NEW.usage_meter_definition_id
      AND event.usage_meter_rate_id = NEW.usage_meter_rate_id
      AND event.source_type = NEW.source_type AND event.source_id = NEW.source_id
      AND event.quantity = NEW.quantity AND event.applied_weight = NEW.applied_weight
      AND event.billed_quantity = NEW.billed_quantity
  ) THEN
    RAISE EXCEPTION 'usage quota allocation event is inconsistent' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: enforce_usage_quota_reservation_lifecycle(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_usage_quota_reservation_lifecycle() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'usage quota reservations cannot be deleted' USING ERRCODE = '23514';
  END IF;

  PERFORM lock_usage_quota_pool(CASE WHEN TG_OP = 'INSERT' THEN NEW.usage_window_id ELSE OLD.usage_window_id END);
  IF TG_OP = 'INSERT' THEN
    RETURN NEW;
  END IF;

  IF OLD.organization_id IS DISTINCT FROM NEW.organization_id OR
    OLD.source_organization_id IS DISTINCT FROM NEW.source_organization_id OR
    OLD.usage_window_id IS DISTINCT FROM NEW.usage_window_id OR
    OLD.usage_meter_definition_id IS DISTINCT FROM NEW.usage_meter_definition_id OR
    OLD.usage_meter_rate_id IS DISTINCT FROM NEW.usage_meter_rate_id OR
    OLD.idempotency_key_digest IS DISTINCT FROM NEW.idempotency_key_digest OR
    OLD.request_checksum IS DISTINCT FROM NEW.request_checksum OR
    OLD.source_type IS DISTINCT FROM NEW.source_type OR OLD.source_id IS DISTINCT FROM NEW.source_id OR
    OLD.limit_kind IS DISTINCT FROM NEW.limit_kind OR OLD.limit_quantity IS DISTINCT FROM NEW.limit_quantity OR
    OLD.entitlement_key IS DISTINCT FROM NEW.entitlement_key OR
    OLD.entitlement_state IS DISTINCT FROM NEW.entitlement_state OR
    OLD.entitlement_provenance IS DISTINCT FROM NEW.entitlement_provenance OR
    OLD.entitlement_definition_checksum IS DISTINCT FROM NEW.entitlement_definition_checksum OR
    OLD.entitlement_override_id IS DISTINCT FROM NEW.entitlement_override_id OR
    OLD.subscription_id IS DISTINCT FROM NEW.subscription_id OR
    OLD.plan_version_id IS DISTINCT FROM NEW.plan_version_id OR
    OLD.subscription_revision IS DISTINCT FROM NEW.subscription_revision OR
    OLD.admitted_at IS DISTINCT FROM NEW.admitted_at OR OLD.created_at IS DISTINCT FROM NEW.created_at THEN
    RAISE EXCEPTION 'usage quota reservation admission snapshot is immutable' USING ERRCODE = '23514';
  END IF;

  IF OLD.state <> 'held' OR NEW.state NOT IN ('held', 'finalized', 'released', 'expired') OR
    NEW.requested_quantity < OLD.requested_quantity OR NEW.held_quantity < OLD.held_quantity OR
    NEW.consumed_quantity < OLD.consumed_quantity OR
    NEW.expires_at < OLD.expires_at THEN
    RAISE EXCEPTION 'usage quota reservation transition is invalid' USING ERRCODE = '23514';
  END IF;
  IF NEW.state = 'finalized' AND NEW.finalized_usage_event_id IS NOT NULL AND NOT EXISTS ( SELECT 1 FROM usage_events event WHERE event.id = NEW.finalized_usage_event_id AND event.organization_id = NEW.organization_id AND event.source_type = NEW.source_type AND event.source_id = NEW.source_id AND event.billed_quantity <= NEW.consumed_quantity ) THEN RAISE EXCEPTION 'usage quota finalization event is inconsistent' USING ERRCODE = '23514'; END IF;
  RETURN NEW;
END;
$$;


--
-- Name: enforce_usage_quota_reservation_operation_immutability(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_usage_quota_reservation_operation_immutability() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP <> 'INSERT' THEN
    RAISE EXCEPTION 'usage quota reservation operations are append-only' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: enforce_usage_window_integrity(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_usage_window_integrity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP <> 'INSERT' THEN
    RAISE EXCEPTION 'usage windows are immutable' USING ERRCODE = '23514';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(NEW.organization_id::text || ':' ||
    NEW.usage_meter_definition_id::text, 0));
  IF EXISTS (
    SELECT 1 FROM usage_windows existing
    WHERE existing.organization_id = NEW.organization_id
      AND existing.usage_meter_definition_id = NEW.usage_meter_definition_id
      AND tstzrange(existing.starts_at, existing.ends_at, '[)') &&
        tstzrange(NEW.starts_at, NEW.ends_at, '[)')
      AND (existing.starts_at, existing.ends_at) <> (NEW.starts_at, NEW.ends_at)
  ) THEN
    RAISE EXCEPTION 'usage windows cannot overlap' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: invalidate_connection_bound_verifications(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.invalidate_connection_bound_verifications() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.external_account_id IS DISTINCT FROM OLD.external_account_id
    OR NEW.granted_scopes IS DISTINCT FROM OLD.granted_scopes
    OR NEW.credential_revision IS DISTINCT FROM OLD.credential_revision
    OR (NEW.state IS DISTINCT FROM OLD.state
      AND NEW.state IN ('reauthorization_required', 'revoked')) THEN
    WITH affected AS (
      UPDATE domain_verifications
      SET state = 'revoked', revoked_at = CURRENT_TIMESTAMP,
        failed_at = NULL, expired_at = NULL, failure_category = NULL,
        lock_version = lock_version + 1, updated_at = CURRENT_TIMESTAMP
      WHERE organization_id = NEW.organization_id
        AND integration_connection_id = NEW.id
        AND method = 'search_console'
        AND state IN ('pending', 'verified')
      RETURNING organization_id, project_id, property_id, environment_id
    )
    UPDATE properties
    SET verification_status = 'unverified', verified_at = NULL,
      lock_version = lock_version + 1, updated_at = CURRENT_TIMESTAMP
    WHERE EXISTS (
      SELECT 1 FROM affected
      JOIN property_environments ON
        property_environments.organization_id = affected.organization_id
        AND property_environments.project_id = affected.project_id
        AND property_environments.property_id = affected.property_id
        AND property_environments.id = affected.environment_id
        AND property_environments."primary" = TRUE
      WHERE properties.organization_id = affected.organization_id
        AND properties.project_id = affected.project_id
        AND properties.id = affected.property_id
    );
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: invalidate_origin_bound_verifications(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.invalidate_origin_bound_verifications() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.origin IS DISTINCT FROM OLD.origin THEN
    UPDATE domain_verifications
    SET state = 'revoked', revoked_at = CURRENT_TIMESTAMP,
      failed_at = NULL, expired_at = NULL, failure_category = NULL,
      lock_version = lock_version + 1, updated_at = CURRENT_TIMESTAMP
    WHERE organization_id = NEW.organization_id
      AND project_id = NEW.project_id
      AND property_id = NEW.property_id
      AND environment_id = NEW.id
      AND bound_origin IS DISTINCT FROM NEW.origin
      AND state IN ('pending', 'verified');

    UPDATE properties
    SET verification_status = 'unverified', verified_at = NULL,
      lock_version = lock_version + 1, updated_at = CURRENT_TIMESTAMP
    WHERE organization_id = NEW.organization_id
      AND project_id = NEW.project_id
      AND id = NEW.property_id
      AND NEW."primary" = TRUE;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: lock_usage_quota_pool(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.lock_usage_quota_pool(reservation_window uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  lock_identity text;
BEGIN
  SELECT concat_ws(':', usage_window.organization_id::text, meter_definition.pool_key,
    meter_definition.billing_unit, COALESCE(meter_definition.quota_entitlement_key, 'unlimited'),
    usage_window.window_policy, usage_window.starts_at::text, usage_window.ends_at::text)
  INTO lock_identity
  FROM usage_windows usage_window
  JOIN usage_meter_definitions meter_definition
    ON meter_definition.id = usage_window.usage_meter_definition_id
  WHERE usage_window.id = reservation_window;

  IF lock_identity IS NULL THEN
    RAISE EXCEPTION 'usage quota window is invalid' USING ERRCODE = '23514';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(lock_identity, 0));
END;
$$;


--
-- Name: prevent_audit_target_tombstone_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_audit_target_tombstone_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'audit target tombstones are append-only';
END;
$$;


--
-- Name: prevent_domain_verification_attempt_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_domain_verification_attempt_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' AND resource_deletion_stage_authorized(
    OLD.organization_id, OLD.project_id, OLD.property_id, 'aggregate_records'
  ) THEN
    RETURN OLD;
  END IF;
  RAISE EXCEPTION 'domain verification attempts are append-only';
END;
$$;


--
-- Name: prevent_plan_deletion(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_plan_deletion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'stable commercial plans cannot be deleted' USING ERRCODE = '23514';
END;
$$;


--
-- Name: protect_crawl_fetch_permit_provenance(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_crawl_fetch_permit_provenance() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF resource_deletion_stage_authorized(
      OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
    ) THEN
      RETURN OLD;
    END IF;
    RAISE EXCEPTION 'crawl fetch permit deletion requires an active lifecycle workflow';
  END IF;

  IF NEW.organization_id IS DISTINCT FROM OLD.organization_id
    OR NEW.project_id IS DISTINCT FROM OLD.project_id
    OR NEW.property_id IS DISTINCT FROM OLD.property_id
    OR NEW.environment_id IS DISTINCT FROM OLD.environment_id
    OR NEW.scan_id IS DISTINCT FROM OLD.scan_id
    OR NEW.crawl_url_id IS DISTINCT FROM OLD.crawl_url_id
    OR NEW.host_key_digest IS DISTINCT FROM OLD.host_key_digest
    OR NEW.worker_id IS DISTINCT FROM OLD.worker_id
    OR NEW.permit_token_digest IS DISTINCT FROM OLD.permit_token_digest
    OR NEW.acquired_at IS DISTINCT FROM OLD.acquired_at
    OR NEW.expires_at IS DISTINCT FROM OLD.expires_at
    OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'crawl fetch permit provenance is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: protect_crawl_fetch_result_rows(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_crawl_fetch_result_rows() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' AND resource_deletion_stage_authorized(
    OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
  ) THEN RETURN OLD; END IF;
  RAISE EXCEPTION 'crawl fetch results are immutable outside an active lifecycle workflow';
END;
$$;


--
-- Name: protect_crawl_link_rows(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_crawl_link_rows() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' AND resource_deletion_stage_authorized(
    OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
  ) THEN RETURN OLD; END IF;
  RAISE EXCEPTION 'crawl links are immutable outside an active lifecycle workflow';
END;
$$;


--
-- Name: protect_crawl_page_fact_rows(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_crawl_page_fact_rows() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' AND resource_deletion_stage_authorized(
    OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
  ) THEN RETURN OLD; END IF;
  RAISE EXCEPTION 'crawl page facts are immutable outside an active lifecycle workflow';
END;
$$;


--
-- Name: protect_crawl_page_render_rows(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_crawl_page_render_rows() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF resource_deletion_stage_authorized(
      OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
    ) THEN RETURN OLD; END IF;
    RAISE EXCEPTION 'crawl page render deletion requires an active lifecycle workflow';
  END IF;
  IF NEW.organization_id IS DISTINCT FROM OLD.organization_id
    OR NEW.project_id IS DISTINCT FROM OLD.project_id
    OR NEW.property_id IS DISTINCT FROM OLD.property_id
    OR NEW.environment_id IS DISTINCT FROM OLD.environment_id
    OR NEW.scan_id IS DISTINCT FROM OLD.scan_id
    OR NEW.page_snapshot_id IS DISTINCT FROM OLD.page_snapshot_id
    OR NEW.page_fact_id IS DISTINCT FROM OLD.page_fact_id
    OR NEW.requested_url IS DISTINCT FROM OLD.requested_url
    OR NEW.requested_url_digest IS DISTINCT FROM OLD.requested_url_digest
    OR NEW.screenshot_enabled IS DISTINCT FROM OLD.screenshot_enabled
    OR NEW.maximum_attempts IS DISTINCT FROM OLD.maximum_attempts
    OR OLD.state IN ('completed', 'failed', 'canceled', 'skipped')
    OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'crawl page render identity or terminal result is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: protect_crawl_page_snapshot_identity(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_crawl_page_snapshot_identity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF resource_deletion_stage_authorized(
      OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
    ) THEN RETURN OLD; END IF;
    RAISE EXCEPTION 'crawl page snapshot deletion requires an active lifecycle workflow';
  END IF;
  IF NEW.organization_id IS DISTINCT FROM OLD.organization_id
    OR NEW.project_id IS DISTINCT FROM OLD.project_id
    OR NEW.property_id IS DISTINCT FROM OLD.property_id
    OR NEW.environment_id IS DISTINCT FROM OLD.environment_id
    OR NEW.scan_id IS DISTINCT FROM OLD.scan_id
    OR NEW.crawl_url_id IS DISTINCT FROM OLD.crawl_url_id
    OR NEW.crawl_fetch_result_id IS DISTINCT FROM OLD.crawl_fetch_result_id
    OR NEW.artifact_id IS DISTINCT FROM OLD.artifact_id
    OR NEW.maximum_extraction_attempts IS DISTINCT FROM OLD.maximum_extraction_attempts
    OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'crawl page snapshot identity is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: protect_crawl_policy_set_deletion(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_crawl_policy_set_deletion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NOT resource_deletion_stage_authorized(
    OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
  ) THEN
    RAISE EXCEPTION 'crawl policy deletion requires an active lifecycle workflow';
  END IF;
  RETURN OLD;
END;
$$;


--
-- Name: protect_crawl_rendered_link_rows(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_crawl_rendered_link_rows() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' AND resource_deletion_stage_authorized(
    OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
  ) THEN RETURN OLD; END IF;
  RAISE EXCEPTION 'crawl rendered links are immutable outside an active lifecycle workflow';
END;
$$;


--
-- Name: protect_crawl_rendered_page_fact_rows(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_crawl_rendered_page_fact_rows() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' AND resource_deletion_stage_authorized(
    OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
  ) THEN RETURN OLD; END IF;
  RAISE EXCEPTION 'crawl rendered page facts are immutable outside an active lifecycle workflow';
END;
$$;


--
-- Name: protect_crawl_robots_snapshot(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_crawl_robots_snapshot() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' AND resource_deletion_stage_authorized(
    OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
  ) THEN
    RETURN OLD;
  END IF;
  RAISE EXCEPTION 'crawl robots snapshots are immutable';
END;
$$;


--
-- Name: protect_crawl_scan_execution_identity(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_crawl_scan_execution_identity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF resource_deletion_stage_authorized(
      OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
    ) THEN RETURN OLD; END IF;
    RAISE EXCEPTION 'crawl execution deletion requires an active lifecycle workflow';
  END IF;
  IF NEW.organization_id IS DISTINCT FROM OLD.organization_id
    OR NEW.project_id IS DISTINCT FROM OLD.project_id
    OR NEW.property_id IS DISTINCT FROM OLD.property_id
    OR NEW.environment_id IS DISTINCT FROM OLD.environment_id
    OR NEW.scan_id IS DISTINCT FROM OLD.scan_id
    OR NEW.maximum_initialization_attempts IS DISTINCT FROM OLD.maximum_initialization_attempts
    OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'crawl execution identity is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: protect_crawl_sitemap_discovery(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_crawl_sitemap_discovery() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF resource_deletion_stage_authorized(
      OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
    ) THEN RETURN OLD; END IF;
    RAISE EXCEPTION 'sitemap discovery deletion requires an active lifecycle workflow';
  END IF;
  IF OLD.status <> 'running' THEN
    RAISE EXCEPTION 'terminal sitemap discoveries are immutable';
  END IF;
  IF NEW.organization_id IS DISTINCT FROM OLD.organization_id
    OR NEW.project_id IS DISTINCT FROM OLD.project_id
    OR NEW.property_id IS DISTINCT FROM OLD.property_id
    OR NEW.environment_id IS DISTINCT FROM OLD.environment_id
    OR NEW.scan_id IS DISTINCT FROM OLD.scan_id
    OR NEW.started_at IS DISTINCT FROM OLD.started_at
    OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'sitemap discovery identity is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: protect_crawl_sitemap_entry(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_crawl_sitemap_entry() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' AND resource_deletion_stage_authorized(
    OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
  ) THEN RETURN OLD; END IF;
  RAISE EXCEPTION 'sitemap entries are immutable';
END;
$$;


--
-- Name: protect_crawl_sitemap_file(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_crawl_sitemap_file() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF resource_deletion_stage_authorized(
      OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
    ) THEN RETURN OLD; END IF;
    RAISE EXCEPTION 'sitemap file deletion requires an active lifecycle workflow';
  END IF;
  IF OLD.status <> 'pending' THEN
    RAISE EXCEPTION 'terminal sitemap files are immutable';
  END IF;
  IF NEW.organization_id IS DISTINCT FROM OLD.organization_id
    OR NEW.project_id IS DISTINCT FROM OLD.project_id
    OR NEW.property_id IS DISTINCT FROM OLD.property_id
    OR NEW.environment_id IS DISTINCT FROM OLD.environment_id
    OR NEW.scan_id IS DISTINCT FROM OLD.scan_id
    OR NEW.sitemap_discovery_id IS DISTINCT FROM OLD.sitemap_discovery_id
    OR NEW.parent_sitemap_file_id IS DISTINCT FROM OLD.parent_sitemap_file_id
    OR NEW.url IS DISTINCT FROM OLD.url
    OR NEW.url_digest IS DISTINCT FROM OLD.url_digest
    OR NEW.source IS DISTINCT FROM OLD.source
    OR NEW.index_depth IS DISTINCT FROM OLD.index_depth
    OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'sitemap file provenance is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: protect_crawl_url_identity(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_crawl_url_identity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF resource_deletion_stage_authorized(
      OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
    ) THEN
      RETURN OLD;
    END IF;
    RAISE EXCEPTION 'crawl URL deletion requires an active lifecycle workflow';
  END IF;

  IF NEW.organization_id IS DISTINCT FROM OLD.organization_id
    OR NEW.project_id IS DISTINCT FROM OLD.project_id
    OR NEW.property_id IS DISTINCT FROM OLD.property_id
    OR NEW.environment_id IS DISTINCT FROM OLD.environment_id
    OR NEW.scan_id IS DISTINCT FROM OLD.scan_id
    OR NEW.fetch_url IS DISTINCT FROM OLD.fetch_url
    OR NEW.normalized_url_digest IS DISTINCT FROM OLD.normalized_url_digest
    OR NEW.normalization_version IS DISTINCT FROM OLD.normalization_version
    OR NEW.normalized_url IS DISTINCT FROM OLD.normalized_url
    OR NEW.host_digest IS DISTINCT FROM OLD.host_digest
    OR NEW.discovery_source IS DISTINCT FROM OLD.discovery_source
    OR NEW.discovered_from_id IS DISTINCT FROM OLD.discovered_from_id
    OR NEW.maximum_attempts IS DISTINCT FROM OLD.maximum_attempts
    OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'crawl URL identity and discovery provenance are immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: protect_domain_verification_binding(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_domain_verification_binding() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.id IS DISTINCT FROM OLD.id
    OR NEW.organization_id IS DISTINCT FROM OLD.organization_id
    OR NEW.project_id IS DISTINCT FROM OLD.project_id
    OR NEW.property_id IS DISTINCT FROM OLD.property_id
    OR NEW.environment_id IS DISTINCT FROM OLD.environment_id
    OR NEW.issued_by_membership_id IS DISTINCT FROM OLD.issued_by_membership_id
    OR NEW.method IS DISTINCT FROM OLD.method
    OR NEW.challenge_digest IS DISTINCT FROM OLD.challenge_digest
    OR NEW.expected_location IS DISTINCT FROM OLD.expected_location
    OR NEW.bound_origin IS DISTINCT FROM OLD.bound_origin
    OR NEW.integration_connection_id IS DISTINCT FROM OLD.integration_connection_id
    OR NEW.provider_property_identifier IS DISTINCT FROM OLD.provider_property_identifier
    OR NEW.provider_property_type IS DISTINCT FROM OLD.provider_property_type
    OR NEW.connection_revision IS DISTINCT FROM OLD.connection_revision
    OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'domain verification binding cannot be changed';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: protect_domain_verification_deletion(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_domain_verification_deletion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NOT resource_deletion_stage_authorized(
    OLD.organization_id, OLD.project_id, OLD.property_id, 'aggregate_records'
  ) THEN
    RAISE EXCEPTION 'domain verification deletion requires an active lifecycle workflow';
  END IF;
  RETURN OLD;
END;
$$;


--
-- Name: protect_project_lifecycle_deletion(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_project_lifecycle_deletion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NOT resource_deletion_stage_authorized(
    OLD.organization_id, OLD.id, NULL, 'aggregate_records'
  ) THEN
    RAISE EXCEPTION 'project deletion requires an active lifecycle workflow';
  END IF;
  RETURN OLD;
END;
$$;


--
-- Name: protect_project_stable_identity(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_project_stable_identity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.organization_id <> OLD.organization_id
    OR NEW.slug <> OLD.slug
    OR NEW.external_release_key <> OLD.external_release_key
    OR NEW.authorization_scope_type <> OLD.authorization_scope_type THEN
    RAISE EXCEPTION 'project stable identity cannot be changed';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: protect_property_environment_stable_identity(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_property_environment_stable_identity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.id IS DISTINCT FROM OLD.id
    OR NEW.organization_id IS DISTINCT FROM OLD.organization_id
    OR NEW.project_id IS DISTINCT FROM OLD.project_id
    OR NEW.property_id IS DISTINCT FROM OLD.property_id
    OR NEW.property_kind IS DISTINCT FROM OLD.property_kind
    OR NEW.configuration_version IS DISTINCT FROM OLD.configuration_version
    OR NEW.key IS DISTINCT FROM OLD.key
    OR NEW.kind IS DISTINCT FROM OLD.kind THEN
    RAISE EXCEPTION 'property environment stable identity cannot be changed';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: protect_property_lifecycle_deletion(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_property_lifecycle_deletion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NOT resource_deletion_stage_authorized(
    OLD.organization_id, OLD.project_id, OLD.id, 'aggregate_records'
  ) THEN
    RAISE EXCEPTION 'property deletion requires an active lifecycle workflow';
  END IF;
  RETURN OLD;
END;
$$;


--
-- Name: protect_property_stable_identity(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_property_stable_identity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.id IS DISTINCT FROM OLD.id
    OR NEW.organization_id IS DISTINCT FROM OLD.organization_id
    OR NEW.project_id IS DISTINCT FROM OLD.project_id
    OR NEW.kind IS DISTINCT FROM OLD.kind
    OR NEW.configuration_version IS DISTINCT FROM OLD.configuration_version
    OR NEW.authorization_scope_type IS DISTINCT FROM OLD.authorization_scope_type
    OR NEW.authorization_project_scope_type IS DISTINCT FROM OLD.authorization_project_scope_type THEN
    RAISE EXCEPTION 'property stable identity cannot be changed';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: protect_scan_event_history(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_scan_event_history() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' AND resource_deletion_stage_authorized(
    OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
  ) THEN
    RETURN OLD;
  END IF;
  RAISE EXCEPTION 'scan events are append-only';
END;
$$;


--
-- Name: protect_scan_inputs(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_scan_inputs() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF resource_deletion_stage_authorized(
      OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
    ) THEN
      RETURN OLD;
    END IF;
    RAISE EXCEPTION 'scan deletion requires an active lifecycle workflow';
  END IF;

  IF NEW.organization_id IS DISTINCT FROM OLD.organization_id
    OR NEW.project_id IS DISTINCT FROM OLD.project_id
    OR NEW.property_id IS DISTINCT FROM OLD.property_id
    OR NEW.environment_id IS DISTINCT FROM OLD.environment_id
    OR NEW.scan_type IS DISTINCT FROM OLD.scan_type
    OR NEW.initiator_type IS DISTINCT FROM OLD.initiator_type
    OR NEW.initiated_by_membership_id IS DISTINCT FROM OLD.initiated_by_membership_id
    OR NEW.settings_snapshot IS DISTINCT FROM OLD.settings_snapshot
    OR NEW.settings_digest IS DISTINCT FROM OLD.settings_digest
    OR NEW.entitlement_snapshot IS DISTINCT FROM OLD.entitlement_snapshot
    OR NEW.entitlement_digest IS DISTINCT FROM OLD.entitlement_digest
    OR NEW.engine_version IS DISTINCT FROM OLD.engine_version
    OR NEW.rule_set_version IS DISTINCT FROM OLD.rule_set_version
    OR NEW.configuration_version IS DISTINCT FROM OLD.configuration_version
    OR NEW.release_id IS DISTINCT FROM OLD.release_id
    OR NEW.baseline_scan_id IS DISTINCT FROM OLD.baseline_scan_id
    OR NEW.requested_at IS DISTINCT FROM OLD.requested_at
    OR NEW.request_source IS DISTINCT FROM OLD.request_source
OR NEW.request_idempotency_digest IS DISTINCT FROM OLD.request_idempotency_digest
OR NEW.request_checksum IS DISTINCT FROM OLD.request_checksum
OR NEW.admission_version IS DISTINCT FROM OLD.admission_version
OR NEW.usage_quota_reservation_id IS DISTINCT FROM OLD.usage_quota_reservation_id
OR NEW.domain_verification_id IS DISTINCT FROM OLD.domain_verification_id
OR NEW.preflight_checked_at IS DISTINCT FROM OLD.preflight_checked_at
OR NEW.preflight_status_code IS DISTINCT FROM OLD.preflight_status_code
OR NEW.preflight_destination_digest IS DISTINCT FROM OLD.preflight_destination_digest
OR NEW.credit_estimate IS DISTINCT FROM OLD.credit_estimate
 THEN
    RAISE EXCEPTION 'scan input and provenance are immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_crawl_policy_immutable_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_crawl_policy_immutable_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' AND resource_deletion_stage_authorized(
    OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
  ) THEN
    RETURN OLD;
  END IF;
  RAISE EXCEPTION '% rows are immutable', TG_TABLE_NAME;
END;
$$;


--
-- Name: resource_deletion_stage_authorized(uuid, uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.resource_deletion_stage_authorized(target_organization_id uuid, target_project_id uuid, target_property_id uuid, required_stage text) RETURNS boolean
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
  workflow_setting text;
BEGIN
  workflow_setting := current_setting('searchops.deletion_workflow_id', TRUE);
  IF workflow_setting IS NULL OR workflow_setting !~
    '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' THEN
    RETURN FALSE;
  END IF;

  RETURN EXISTS (
    SELECT 1 FROM resource_deletion_workflows workflows
    WHERE workflows.id = workflow_setting::uuid
      AND workflows.organization_id = target_organization_id
      AND workflows.project_id = target_project_id
      AND (workflows.target_type = 'Project'
        OR (workflows.target_type = 'Property' AND workflows.property_id = target_property_id))
      AND workflows.state = 'running'
      AND workflows.current_stage = required_stage
      AND workflows.hold_until <= CURRENT_TIMESTAMP
      AND workflows.lease_expires_at > CURRENT_TIMESTAMP
  );
END;
$_$;


--
-- Name: validate_domain_verification_origin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_domain_verification_origin() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  PERFORM 1 FROM property_environments
  WHERE organization_id = NEW.organization_id
    AND project_id = NEW.project_id
    AND property_id = NEW.property_id
    AND id = NEW.environment_id
    AND status = 'active'
    AND origin = NEW.bound_origin
  FOR KEY SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'domain verification origin does not match active environment';
  END IF;
  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: android_property_configs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.android_property_configs (
    property_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_kind character varying(32) DEFAULT 'android_app'::character varying NOT NULL,
    configuration_version integer DEFAULT 1 NOT NULL,
    package_name public.citext NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT android_configs_package_format CHECK ((((package_name)::text = lower((package_name)::text)) AND ((package_name)::text ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'::text))),
    CONSTRAINT android_configs_type_and_version CHECK ((((property_kind)::text = 'android_app'::text) AND (configuration_version = 1)))
);


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: artifact_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.artifact_blobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid NOT NULL,
    storage_service character varying(24) NOT NULL,
    object_key character varying(512) NOT NULL,
    byte_count bigint NOT NULL,
    content_sha256 character varying(64) NOT NULL,
    encryption_mode character varying(32) DEFAULT 'provider_managed'::character varying NOT NULL,
    encryption_key_version character varying(64) NOT NULL,
    state character varying(24) DEFAULT 'uploading'::character varying NOT NULL,
    stored_at timestamp(6) with time zone,
    verified_at timestamp(6) with time zone,
    missing_at timestamp(6) with time zone,
    deleted_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT artifact_blobs_lifecycle CHECK ((((state)::text = ANY (ARRAY[('uploading'::character varying)::text, ('active'::character varying)::text, ('missing'::character varying)::text, ('deleting'::character varying)::text, ('deleted'::character varying)::text])) AND (((state)::text <> 'uploading'::text) OR ((stored_at IS NULL) AND (missing_at IS NULL) AND (deleted_at IS NULL))) AND (((state)::text <> 'active'::text) OR ((stored_at IS NOT NULL) AND (missing_at IS NULL) AND (deleted_at IS NULL))) AND (((state)::text <> 'missing'::text) OR ((stored_at IS NOT NULL) AND (missing_at IS NOT NULL) AND (deleted_at IS NULL))) AND (((state)::text <> 'deleted'::text) OR (deleted_at IS NOT NULL)))),
    CONSTRAINT artifact_blobs_metadata_shape CHECK ((((storage_service)::text ~ '^[a-z][a-z0-9_]{0,23}$'::text) AND (byte_count >= 0) AND ((content_sha256)::text ~ '^[0-9a-f]{64}$'::text) AND ((encryption_mode)::text = ANY (ARRAY[('provider_managed'::character varying)::text, ('sse_s3'::character varying)::text, ('local_private'::character varying)::text])) AND ((encryption_key_version)::text ~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$'::text))),
    CONSTRAINT artifact_blobs_opaque_scoped_key CHECK (((octet_length((object_key)::text) >= 32) AND (octet_length((object_key)::text) <= 512) AND ((object_key)::text !~ '[[:cntrl:]]'::text) AND ((object_key)::text ~~ (((((('organizations/'::text || (organization_id)::text) || '/projects/'::text) || (project_id)::text) || '/properties/'::text) || (property_id)::text) || '/objects/%'::text))))
);


--
-- Name: artifacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.artifacts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid NOT NULL,
    environment_id uuid NOT NULL,
    scan_id uuid NOT NULL,
    artifact_blob_id uuid NOT NULL,
    source_type character varying(48) NOT NULL,
    source_id character varying(128) NOT NULL,
    kind character varying(48) NOT NULL,
    media_type character varying(128) NOT NULL,
    download_filename character varying(160) NOT NULL,
    retention_class character varying(48) NOT NULL,
    retention_state character varying(24) DEFAULT 'retained'::character varying NOT NULL,
    retention_expires_at timestamp(6) with time zone NOT NULL,
    legal_hold boolean DEFAULT false NOT NULL,
    legal_hold_set_at timestamp(6) with time zone,
    deletion_requested_at timestamp(6) with time zone,
    deleted_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT artifacts_metadata_shape CHECK ((((source_type)::text ~ '^[a-z][a-z0-9_]{0,47}$'::text) AND ((octet_length((source_id)::text) >= 1) AND (octet_length((source_id)::text) <= 128)) AND ((source_id)::text !~ '[[:cntrl:]]'::text) AND ((kind)::text ~ '^[a-z][a-z0-9_]{0,47}$'::text) AND ((media_type)::text ~ '^[a-z0-9!#$&^_.+-]+/[a-z0-9!#$&^_.+-]+$'::text) AND ((octet_length((download_filename)::text) >= 1) AND (octet_length((download_filename)::text) <= 160)) AND ((download_filename)::text !~ '[[:cntrl:]/\\]'::text) AND ((retention_class)::text ~ '^[a-z][a-z0-9_]{0,47}$'::text))),
    CONSTRAINT artifacts_retention_lifecycle CHECK ((((retention_state)::text = ANY (ARRAY[('retained'::character varying)::text, ('deletion_pending'::character varying)::text, ('missing'::character varying)::text, ('deleted'::character varying)::text])) AND ((legal_hold AND (legal_hold_set_at IS NOT NULL)) OR ((NOT legal_hold) AND (legal_hold_set_at IS NULL))) AND (((retention_state)::text = 'retained'::text) OR (deletion_requested_at IS NOT NULL)) AND (((retention_state)::text <> 'deleted'::text) OR (deleted_at IS NOT NULL))))
);


--
-- Name: audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    action character varying(96) NOT NULL,
    actor_membership_id uuid,
    actor_type character varying(24) NOT NULL,
    actor_user_id uuid,
    created_at timestamp(6) with time zone NOT NULL,
    job_id character varying(128),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    occurred_at timestamp(6) with time zone NOT NULL,
    organization_id uuid,
    request_id character varying(128),
    result character varying(24) NOT NULL,
    source_ip_digest character varying(64),
    target_id uuid,
    target_type character varying(48) NOT NULL,
    trace_id character varying(128),
    user_agent_digest character varying(64),
    CONSTRAINT audit_events_action_format CHECK (((action)::text ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'::text)),
    CONSTRAINT audit_events_actor_shape CHECK (((((actor_type)::text = 'Membership'::text) AND (organization_id IS NOT NULL) AND (actor_membership_id IS NOT NULL) AND (actor_user_id IS NULL)) OR (((actor_type)::text = 'User'::text) AND (actor_membership_id IS NULL) AND (actor_user_id IS NOT NULL)) OR (((actor_type)::text = 'System'::text) AND (actor_membership_id IS NULL) AND (actor_user_id IS NULL)))),
    CONSTRAINT audit_events_client_digest_shape CHECK ((((source_ip_digest IS NULL) OR ((source_ip_digest)::text ~ '^[0-9a-f]{64}$'::text)) AND ((user_agent_digest IS NULL) OR ((user_agent_digest)::text ~ '^[0-9a-f]{64}$'::text)))),
    CONSTRAINT audit_events_metadata_bounded CHECK (((jsonb_typeof(metadata) = 'object'::text) AND (pg_column_size(metadata) <= 8192))),
    CONSTRAINT audit_events_result_allowlist CHECK (((result)::text = ANY (ARRAY[('succeeded'::character varying)::text, ('denied'::character varying)::text, ('failed'::character varying)::text, ('ignored'::character varying)::text]))),
    CONSTRAINT audit_events_target_type_format CHECK (((target_type)::text ~ '^[A-Z][A-Za-z0-9]{0,47}$'::text))
);


--
-- Name: audit_target_tombstones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_target_tombstones (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    deletion_workflow_id uuid NOT NULL,
    target_type character varying(48) NOT NULL,
    target_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid,
    deleted_at timestamp(6) with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT audit_tombstones_target_type CHECK (((target_type)::text = ANY (ARRAY[('Project'::character varying)::text, ('Property'::character varying)::text, ('PropertyEnvironment'::character varying)::text, ('DomainVerification'::character varying)::text, ('CrawlPolicy'::character varying)::text, ('Scan'::character varying)::text])))
);


--
-- Name: authentication_rate_limit_buckets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.authentication_rate_limit_buckets (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    key_digest character varying(64) NOT NULL,
    request_count integer NOT NULL,
    scope character varying(64) NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    window_started_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT authentication_rate_limits_bounded_window CHECK ((expires_at > window_started_at)),
    CONSTRAINT authentication_rate_limits_key_digest_format CHECK (((key_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT authentication_rate_limits_positive_count CHECK ((request_count > 0)),
    CONSTRAINT authentication_rate_limits_scope_allowlist CHECK (((scope)::text = ANY (ARRAY[('oauth_start_ip'::character varying)::text, ('oauth_link_session'::character varying)::text, ('oauth_callback_failure_ip'::character varying)::text, ('session_action_session'::character varying)::text, ('account_security_session'::character varying)::text])))
);


--
-- Name: authentication_rate_limit_buckets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.authentication_rate_limit_buckets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: authentication_rate_limit_buckets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.authentication_rate_limit_buckets_id_seq OWNED BY public.authentication_rate_limit_buckets.id;


--
-- Name: authorization_catalog_revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.authorization_catalog_revisions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    checksum character varying(64) NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    permission_count integer NOT NULL,
    role_count integer NOT NULL,
    schema_version integer NOT NULL,
    source_path character varying(255) NOT NULL,
    synced_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT authorization_catalog_revisions_checksum_format CHECK (((checksum)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT authorization_catalog_revisions_positive_counts CHECK (((permission_count > 0) AND (role_count > 0))),
    CONSTRAINT authorization_catalog_revisions_positive_schema CHECK ((schema_version > 0)),
    CONSTRAINT authorization_catalog_revisions_source_path CHECK (((source_path)::text = 'config_blueprints/permissions.yml'::text))
);


--
-- Name: authorization_scope_references; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.authorization_scope_references (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    archived_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid,
    project_scope_type character varying(24),
    scope_type character varying(24) NOT NULL,
    status character varying(24) DEFAULT 'active'::character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT authorization_scopes_lifecycle CHECK (((((status)::text = 'active'::text) AND (archived_at IS NULL)) OR (((status)::text = 'archived'::text) AND (archived_at IS NOT NULL)))),
    CONSTRAINT authorization_scopes_shape CHECK (((((scope_type)::text = 'Organization'::text) AND (id = organization_id) AND (project_id IS NULL) AND (project_scope_type IS NULL)) OR (((scope_type)::text = 'Project'::text) AND (id <> organization_id) AND (project_id IS NULL) AND (project_scope_type IS NULL)) OR (((scope_type)::text = 'Property'::text) AND (id <> organization_id) AND (project_id IS NOT NULL) AND ((project_scope_type)::text = 'Project'::text) AND (id <> project_id)))),
    CONSTRAINT authorization_scopes_type_allowlist CHECK (((scope_type)::text = ANY (ARRAY[('Organization'::character varying)::text, ('Project'::character varying)::text, ('Property'::character varying)::text])))
);


--
-- Name: billing_checkout_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.billing_checkout_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    plan_version_id uuid NOT NULL,
    actor_membership_id uuid NOT NULL,
    billing_customer_id uuid,
    provider character varying(32) NOT NULL,
    environment character varying(16) NOT NULL,
    currency character varying(3) NOT NULL,
    billing_interval character varying(16) NOT NULL,
    state character varying(16) DEFAULT 'preparing'::character varying NOT NULL,
    idempotency_digest character varying(64) NOT NULL,
    provider_checkout_id character varying(191),
    failure_category character varying(64),
    expires_at timestamp(6) with time zone NOT NULL,
    ready_at timestamp(6) with time zone,
    failed_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT billing_checkouts_currency_format CHECK (((currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT billing_checkouts_environment_allowlist CHECK (((environment)::text = ANY (ARRAY[('development'::character varying)::text, ('test'::character varying)::text, ('staging'::character varying)::text, ('production'::character varying)::text]))),
    CONSTRAINT billing_checkouts_expiration_order CHECK ((expires_at > created_at)),
    CONSTRAINT billing_checkouts_failure_category_format CHECK (((failure_category IS NULL) OR ((failure_category)::text ~ '^[a-z][a-z0-9_]{0,63}$'::text))),
    CONSTRAINT billing_checkouts_idempotency_digest_format CHECK (((idempotency_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT billing_checkouts_interval_allowlist CHECK (((billing_interval)::text = ANY (ARRAY[('monthly'::character varying)::text, ('annual'::character varying)::text]))),
    CONSTRAINT billing_checkouts_lifecycle_shape CHECK (((((state)::text = 'preparing'::text) AND (provider_checkout_id IS NULL) AND (ready_at IS NULL) AND (failed_at IS NULL) AND (failure_category IS NULL)) OR (((state)::text = 'ready'::text) AND (billing_customer_id IS NOT NULL) AND (provider_checkout_id IS NOT NULL) AND (ready_at IS NOT NULL) AND (failed_at IS NULL) AND (failure_category IS NULL)) OR (((state)::text = 'uncertain'::text) AND (provider_checkout_id IS NULL) AND (ready_at IS NULL) AND (failed_at IS NOT NULL) AND (failure_category IS NOT NULL)) OR (((state)::text = 'failed'::text) AND (provider_checkout_id IS NULL) AND (ready_at IS NULL) AND (failed_at IS NOT NULL) AND (failure_category IS NOT NULL)) OR ((state)::text = 'expired'::text))),
    CONSTRAINT billing_checkouts_provider_format CHECK (((provider)::text ~ '^[a-z][a-z0-9_]{1,31}$'::text)),
    CONSTRAINT billing_checkouts_provider_id_format CHECK (((provider_checkout_id IS NULL) OR ((provider_checkout_id)::text ~ '^[A-Za-z0-9][A-Za-z0-9_.:-]{0,190}$'::text))),
    CONSTRAINT billing_checkouts_state_allowlist CHECK (((state)::text = ANY (ARRAY[('preparing'::character varying)::text, ('ready'::character varying)::text, ('uncertain'::character varying)::text, ('failed'::character varying)::text, ('expired'::character varying)::text])))
);


--
-- Name: billing_customers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.billing_customers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    provider character varying(32) NOT NULL,
    environment character varying(16) NOT NULL,
    provider_customer_id character varying(191) NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT billing_customers_environment_allowlist CHECK (((environment)::text = ANY (ARRAY[('development'::character varying)::text, ('test'::character varying)::text, ('staging'::character varying)::text, ('production'::character varying)::text]))),
    CONSTRAINT billing_customers_provider_format CHECK (((provider)::text ~ '^[a-z][a-z0-9_]{1,31}$'::text)),
    CONSTRAINT billing_customers_provider_id_format CHECK (((provider_customer_id)::text ~ '^[A-Za-z0-9][A-Za-z0-9_.:-]{0,190}$'::text))
);


--
-- Name: billing_plan_provider_mappings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.billing_plan_provider_mappings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    plan_version_id uuid NOT NULL,
    provider character varying(32) NOT NULL,
    environment character varying(16) NOT NULL,
    currency character varying(3) NOT NULL,
    billing_interval character varying(16) NOT NULL,
    provider_variant_id character varying(128) NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    provider_store_id character varying(128),
    provider_product_id character varying(128),
    CONSTRAINT billing_plan_mappings_catalog_coordinates_shape CHECK ((((provider_store_id IS NULL) AND (provider_product_id IS NULL)) OR ((provider_store_id IS NOT NULL) AND (provider_product_id IS NOT NULL)))),
    CONSTRAINT billing_plan_mappings_currency_format CHECK (((currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT billing_plan_mappings_environment_allowlist CHECK (((environment)::text = ANY (ARRAY[('development'::character varying)::text, ('test'::character varying)::text, ('staging'::character varying)::text, ('production'::character varying)::text]))),
    CONSTRAINT billing_plan_mappings_interval_allowlist CHECK (((billing_interval)::text = ANY (ARRAY[('monthly'::character varying)::text, ('annual'::character varying)::text]))),
    CONSTRAINT billing_plan_mappings_lemon_squeezy_coordinates CHECK ((((provider)::text <> 'lemon_squeezy'::text) OR ((provider_store_id IS NOT NULL) AND (provider_product_id IS NOT NULL) AND ((provider_store_id)::text ~ '^[1-9][0-9]{0,18}$'::text) AND ((provider_product_id)::text ~ '^[1-9][0-9]{0,18}$'::text) AND ((provider_variant_id)::text ~ '^[1-9][0-9]{0,18}$'::text)))),
    CONSTRAINT billing_plan_mappings_provider_format CHECK (((provider)::text ~ '^[a-z][a-z0-9_]{1,31}$'::text)),
    CONSTRAINT billing_plan_mappings_variant_format CHECK (((provider_variant_id)::text ~ '^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$'::text))
);


--
-- Name: billing_reconciliation_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.billing_reconciliation_runs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    subscription_id uuid NOT NULL,
    requested_by_user_id uuid,
    provider character varying(32) NOT NULL,
    environment character varying(16) NOT NULL,
    source character varying(16) NOT NULL,
    state character varying(16) DEFAULT 'queued'::character varying NOT NULL,
    provider_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    difference_fields jsonb DEFAULT '[]'::jsonb NOT NULL,
    failure_category character varying(64),
    requested_at timestamp(6) with time zone NOT NULL,
    enqueued_at timestamp(6) with time zone,
    started_at timestamp(6) with time zone,
    completed_at timestamp(6) with time zone,
    next_attempt_at timestamp(6) with time zone,
    provider_updated_at timestamp(6) with time zone,
    attempt_count integer DEFAULT 0 NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT billing_reconciliations_attempt_range CHECK (((attempt_count >= 0) AND (attempt_count <= 5))),
    CONSTRAINT billing_reconciliations_differences_bounded CHECK (((jsonb_typeof(difference_fields) = 'array'::text) AND (pg_column_size(difference_fields) <= 2048))),
    CONSTRAINT billing_reconciliations_enqueue_order CHECK (((enqueued_at IS NULL) OR (enqueued_at >= requested_at))),
    CONSTRAINT billing_reconciliations_environment_allowlist CHECK (((environment)::text = ANY (ARRAY[('development'::character varying)::text, ('test'::character varying)::text, ('staging'::character varying)::text, ('production'::character varying)::text]))),
    CONSTRAINT billing_reconciliations_lifecycle_shape CHECK (((((state)::text = 'queued'::text) AND (attempt_count = 0) AND (started_at IS NULL) AND (completed_at IS NULL) AND (next_attempt_at IS NULL) AND (failure_category IS NULL)) OR (((state)::text = 'running'::text) AND (attempt_count > 0) AND (started_at IS NOT NULL) AND (completed_at IS NULL) AND (next_attempt_at IS NULL) AND (failure_category IS NULL)) OR (((state)::text = 'retryable'::text) AND (attempt_count > 0) AND (started_at IS NOT NULL) AND (completed_at IS NULL) AND (next_attempt_at IS NOT NULL) AND (failure_category IS NOT NULL)) OR (((state)::text = ANY (ARRAY[('matched'::character varying)::text, ('repaired'::character varying)::text, ('ambiguous'::character varying)::text])) AND (attempt_count > 0) AND (started_at IS NOT NULL) AND (completed_at IS NOT NULL) AND (next_attempt_at IS NULL) AND (failure_category IS NULL)) OR (((state)::text = ANY (ARRAY[('missing'::character varying)::text, ('failed'::character varying)::text])) AND (attempt_count > 0) AND (started_at IS NOT NULL) AND (completed_at IS NOT NULL) AND (next_attempt_at IS NULL) AND (failure_category IS NOT NULL)))),
    CONSTRAINT billing_reconciliations_provider_format CHECK (((provider)::text ~ '^[a-z][a-z0-9_]{1,31}$'::text)),
    CONSTRAINT billing_reconciliations_requester_shape CHECK (((((source)::text = 'scheduled'::text) AND (requested_by_user_id IS NULL)) OR (((source)::text = 'targeted'::text) AND (requested_by_user_id IS NOT NULL)))),
    CONSTRAINT billing_reconciliations_snapshot_bounded CHECK (((jsonb_typeof(provider_snapshot) = 'object'::text) AND (pg_column_size(provider_snapshot) <= 8192))),
    CONSTRAINT billing_reconciliations_source_allowlist CHECK (((source)::text = ANY (ARRAY[('scheduled'::character varying)::text, ('targeted'::character varying)::text]))),
    CONSTRAINT billing_reconciliations_state_allowlist CHECK (((state)::text = ANY (ARRAY[('queued'::character varying)::text, ('running'::character varying)::text, ('matched'::character varying)::text, ('repaired'::character varying)::text, ('ambiguous'::character varying)::text, ('missing'::character varying)::text, ('retryable'::character varying)::text, ('failed'::character varying)::text])))
);


--
-- Name: billing_subscription_changes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.billing_subscription_changes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    subscription_id uuid NOT NULL,
    from_plan_version_id uuid NOT NULL,
    target_plan_version_id uuid NOT NULL,
    requested_by_membership_id uuid NOT NULL,
    target_billing_interval character varying(16) NOT NULL,
    direction character varying(16) NOT NULL,
    effective_policy character varying(16) NOT NULL,
    state character varying(16) NOT NULL,
    idempotency_digest character varying(64) NOT NULL,
    request_checksum character varying(64) NOT NULL,
    requested_at timestamp(6) with time zone NOT NULL,
    effective_at timestamp(6) with time zone NOT NULL,
    dispatch_enqueued_at timestamp(6) with time zone,
    submitted_at timestamp(6) with time zone,
    applied_at timestamp(6) with time zone,
    failed_at timestamp(6) with time zone,
    failure_category character varying(64),
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT billing_changes_digest_format CHECK ((((idempotency_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((request_checksum)::text ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT billing_changes_direction_allowlist CHECK (((direction)::text = ANY (ARRAY[('upgrade'::character varying)::text, ('downgrade'::character varying)::text]))),
    CONSTRAINT billing_changes_distinct_plan_versions CHECK ((from_plan_version_id <> target_plan_version_id)),
    CONSTRAINT billing_changes_interval_allowlist CHECK (((target_billing_interval)::text = ANY (ARRAY[('monthly'::character varying)::text, ('annual'::character varying)::text]))),
    CONSTRAINT billing_changes_lifecycle_shape CHECK (((effective_at >= requested_at) AND ((dispatch_enqueued_at IS NULL) OR (dispatch_enqueued_at >= requested_at)) AND ((((direction)::text = 'upgrade'::text) AND ((effective_policy)::text = 'immediate'::text) AND ((state)::text <> 'scheduled'::text)) OR (((direction)::text = 'downgrade'::text) AND ((effective_policy)::text = 'period_end'::text) AND ((state)::text <> 'pending'::text))) AND ((((state)::text = ANY (ARRAY[('pending'::character varying)::text, ('scheduled'::character varying)::text])) AND (submitted_at IS NULL) AND (applied_at IS NULL) AND (failed_at IS NULL) AND (failure_category IS NULL)) OR (((state)::text = 'submitted'::text) AND (submitted_at IS NOT NULL) AND (applied_at IS NULL) AND (failed_at IS NULL) AND (failure_category IS NULL)) OR (((state)::text = 'applied'::text) AND (submitted_at IS NOT NULL) AND (applied_at IS NOT NULL) AND (failed_at IS NULL) AND (failure_category IS NULL)) OR (((state)::text = 'failed'::text) AND (applied_at IS NULL) AND (failed_at IS NOT NULL) AND (failure_category IS NOT NULL)) OR (((state)::text = 'canceled'::text) AND (applied_at IS NULL) AND (failed_at IS NULL) AND (failure_category IS NULL))))),
    CONSTRAINT billing_changes_policy_allowlist CHECK (((effective_policy)::text = ANY (ARRAY[('immediate'::character varying)::text, ('period_end'::character varying)::text]))),
    CONSTRAINT billing_changes_state_allowlist CHECK (((state)::text = ANY (ARRAY[('pending'::character varying)::text, ('scheduled'::character varying)::text, ('submitted'::character varying)::text, ('applied'::character varying)::text, ('failed'::character varying)::text, ('canceled'::character varying)::text])))
);


--
-- Name: billing_support_access_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.billing_support_access_grants (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    permission character varying(32) NOT NULL,
    granted_at timestamp(6) with time zone NOT NULL,
    revoked_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT billing_support_grants_permission_allowlist CHECK (((permission)::text = ANY (ARRAY[('billing_support.read'::character varying)::text, ('billing_support.manage'::character varying)::text]))),
    CONSTRAINT billing_support_grants_revocation_order CHECK (((revoked_at IS NULL) OR (revoked_at >= granted_at)))
);


--
-- Name: billing_webhook_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.billing_webhook_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    provider character varying(32) NOT NULL,
    environment character varying(16) NOT NULL,
    provider_event_id character varying(191) NOT NULL,
    event_type character varying(64) NOT NULL,
    payload_checksum character varying(64) NOT NULL,
    payload_ciphertext text NOT NULL,
    request_headers jsonb DEFAULT '{}'::jsonb NOT NULL,
    state character varying(16) DEFAULT 'pending'::character varying NOT NULL,
    attempt_count integer DEFAULT 0 NOT NULL,
    duplicate_count integer DEFAULT 0 NOT NULL,
    conflict_count integer DEFAULT 0 NOT NULL,
    last_error_category character varying(64),
    received_at timestamp(6) with time zone NOT NULL,
    last_received_at timestamp(6) with time zone NOT NULL,
    last_attempted_at timestamp(6) with time zone,
    processed_at timestamp(6) with time zone,
    failed_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    parser_version integer DEFAULT 1 NOT NULL,
    processing_result character varying(24),
    replay_count integer DEFAULT 0 NOT NULL,
    next_attempt_at timestamp(6) with time zone,
    organization_id uuid,
    subscription_id uuid,
    CONSTRAINT billing_webhooks_checksum_format CHECK (((payload_checksum)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT billing_webhooks_ciphertext_size CHECK (((octet_length(payload_ciphertext) >= 1) AND (octet_length(payload_ciphertext) <= 1048576))),
    CONSTRAINT billing_webhooks_environment_allowlist CHECK (((environment)::text = ANY (ARRAY[('development'::character varying)::text, ('test'::character varying)::text, ('staging'::character varying)::text, ('production'::character varying)::text]))),
    CONSTRAINT billing_webhooks_event_id_format CHECK (((provider_event_id)::text ~ '^[A-Za-z0-9][A-Za-z0-9_.:-]{0,190}$'::text)),
    CONSTRAINT billing_webhooks_event_type_format CHECK (((event_type)::text ~ '^[a-z][a-z0-9_.-]{0,63}$'::text)),
    CONSTRAINT billing_webhooks_headers_object CHECK ((jsonb_typeof(request_headers) = 'object'::text)),
    CONSTRAINT billing_webhooks_lifecycle_shape CHECK (((((state)::text = 'pending'::text) AND (processed_at IS NULL) AND (failed_at IS NULL) AND (last_error_category IS NULL) AND (processing_result IS NULL) AND (((attempt_count = 0) AND (last_attempted_at IS NULL)) OR ((attempt_count > 0) AND (last_attempted_at IS NOT NULL) AND (replay_count > 0)))) OR (((state)::text = 'processing'::text) AND (attempt_count > 0) AND (last_attempted_at IS NOT NULL) AND (processed_at IS NULL) AND (failed_at IS NULL) AND (last_error_category IS NULL) AND (processing_result IS NULL) AND (next_attempt_at IS NULL)) OR (((state)::text = 'processed'::text) AND (attempt_count > 0) AND (last_attempted_at IS NOT NULL) AND (processed_at IS NOT NULL) AND (failed_at IS NULL) AND (last_error_category IS NULL) AND (processing_result IS NOT NULL) AND (next_attempt_at IS NULL)) OR (((state)::text = ANY (ARRAY[('retryable'::character varying)::text, ('dead_letter'::character varying)::text])) AND (attempt_count > 0) AND (last_attempted_at IS NOT NULL) AND (processed_at IS NULL) AND (failed_at IS NOT NULL) AND (last_error_category IS NOT NULL) AND (processing_result IS NULL) AND ((((state)::text = 'retryable'::text) AND (next_attempt_at IS NOT NULL)) OR (((state)::text = 'dead_letter'::text) AND (next_attempt_at IS NULL)))))),
    CONSTRAINT billing_webhooks_nonnegative_counts CHECK (((attempt_count >= 0) AND (duplicate_count >= 0) AND (conflict_count >= 0))),
    CONSTRAINT billing_webhooks_nonnegative_replays CHECK ((replay_count >= 0)),
    CONSTRAINT billing_webhooks_parser_version_range CHECK (((parser_version >= 1) AND (parser_version <= 32767))),
    CONSTRAINT billing_webhooks_provider_format CHECK (((provider)::text ~ '^[a-z][a-z0-9_]{1,31}$'::text)),
    CONSTRAINT billing_webhooks_receive_order CHECK ((last_received_at >= received_at)),
    CONSTRAINT billing_webhooks_result_allowlist CHECK (((processing_result IS NULL) OR ((processing_result)::text = ANY (ARRAY[('applied'::character varying)::text, ('stale'::character varying)::text, ('observed'::character varying)::text, ('ignored'::character varying)::text])))),
    CONSTRAINT billing_webhooks_state_allowlist CHECK (((state)::text = ANY (ARRAY[('pending'::character varying)::text, ('processing'::character varying)::text, ('processed'::character varying)::text, ('retryable'::character varying)::text, ('dead_letter'::character varying)::text]))),
    CONSTRAINT billing_webhooks_subscription_tenant_present CHECK (((subscription_id IS NULL) OR (organization_id IS NOT NULL)))
);


--
-- Name: crawl_control_access_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crawl_control_access_grants (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    permission character varying(64) NOT NULL,
    granted_at timestamp(6) with time zone NOT NULL,
    revoked_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT crawl_control_access_grants_permission CHECK (((permission)::text = 'crawler_control.manage'::text)),
    CONSTRAINT crawl_control_access_grants_revocation_time CHECK (((revoked_at IS NULL) OR (revoked_at >= granted_at)))
);


--
-- Name: crawl_fetch_permits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crawl_fetch_permits (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid NOT NULL,
    environment_id uuid NOT NULL,
    scan_id uuid NOT NULL,
    crawl_url_id bigint NOT NULL,
    host_key_digest character varying(64) NOT NULL,
    worker_id character varying(128) NOT NULL,
    permit_token_digest character varying(64) NOT NULL,
    state character varying(24) DEFAULT 'active'::character varying NOT NULL,
    acquired_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    released_at timestamp(6) with time zone,
    release_outcome character varying(24),
    failure_category character varying(64),
    http_status_code integer,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT crawl_fetch_permits_identity_shape CHECK ((((host_key_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((worker_id)::text ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$'::text) AND ((permit_token_digest)::text ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT crawl_fetch_permits_lifecycle_shape CHECK ((((state)::text = ANY (ARRAY[('active'::character varying)::text, ('released'::character varying)::text, ('expired'::character varying)::text])) AND (expires_at > acquired_at) AND ((((state)::text = 'active'::text) AND (released_at IS NULL) AND (release_outcome IS NULL) AND (failure_category IS NULL) AND (http_status_code IS NULL)) OR (((state)::text = ANY (ARRAY[('released'::character varying)::text, ('expired'::character varying)::text])) AND (released_at IS NOT NULL) AND (released_at >= acquired_at) AND ((release_outcome)::text = ANY (ARRAY[('succeeded'::character varying)::text, ('http_error'::character varying)::text, ('failed'::character varying)::text, ('canceled'::character varying)::text, ('expired'::character varying)::text])) AND ((((state)::text = 'released'::text) AND ((release_outcome)::text <> 'expired'::text)) OR (((state)::text = 'expired'::text) AND ((release_outcome)::text = 'expired'::text))))))),
    CONSTRAINT crawl_fetch_permits_result_shape CHECK ((((failure_category IS NULL) OR ((failure_category)::text ~ '^[a-z][a-z0-9_]{0,63}$'::text)) AND ((http_status_code IS NULL) OR ((http_status_code >= 100) AND (http_status_code <= 599))) AND (((state)::text <> 'expired'::text) OR (((release_outcome)::text = 'expired'::text) AND ((failure_category)::text = 'permit_expired'::text) AND (http_status_code IS NULL)))))
);


--
-- Name: crawl_fetch_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crawl_fetch_results (
    id bigint NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid NOT NULL,
    environment_id uuid NOT NULL,
    scan_id uuid NOT NULL,
    crawl_url_id bigint NOT NULL,
    artifact_id uuid,
    attempt_number integer NOT NULL,
    source_key_digest character varying(64) NOT NULL,
    lease_token_digest character varying(64) NOT NULL,
    request_method character varying(8) DEFAULT 'GET'::character varying NOT NULL,
    outcome character varying(24) NOT NULL,
    failure_category character varying(64),
    http_status_code integer,
    final_url text NOT NULL,
    final_url_digest character varying(64) NOT NULL,
    media_type character varying(128),
    charset character varying(64),
    content_encoding character varying(64) NOT NULL,
    response_headers jsonb DEFAULT '{}'::jsonb NOT NULL,
    header_bytes bigint DEFAULT 0 NOT NULL,
    compressed_bytes bigint DEFAULT 0 NOT NULL,
    decoded_bytes bigint DEFAULT 0 NOT NULL,
    body_sha256 character varying(64) NOT NULL,
    sniffed_kind character varying(24) NOT NULL,
    request_count integer NOT NULL,
    retry_count integer NOT NULL,
    redirect_count integer NOT NULL,
    duration_ms integer NOT NULL,
    fetched_at timestamp(6) with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT crawl_fetch_results_bounded_shape CHECK (((jsonb_typeof(response_headers) = 'object'::text) AND (pg_column_size(response_headers) <= 16384) AND ((header_bytes >= 0) AND (header_bytes <= 262144)) AND ((compressed_bytes >= 0) AND (compressed_bytes <= 104857600)) AND ((decoded_bytes >= 0) AND (decoded_bytes <= 524288000)) AND ((request_count >= 0) AND (request_count <= 32)) AND ((retry_count >= 0) AND (retry_count <= 10)) AND ((redirect_count >= 0) AND (redirect_count <= 20)) AND ((duration_ms >= 0) AND (duration_ms <= 600000)) AND (retry_count <= request_count) AND (redirect_count <= request_count) AND ((sniffed_kind)::text = ANY ((ARRAY['empty'::character varying, 'html'::character varying, 'xml'::character varying, 'json'::character varying, 'pdf'::character varying, 'image'::character varying, 'text'::character varying, 'binary'::character varying, 'unknown'::character varying])::text[])))),
    CONSTRAINT crawl_fetch_results_metadata_shape CHECK ((((octet_length(final_url) >= 1) AND (octet_length(final_url) <= 8192)) AND ((final_url_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((body_sha256)::text ~ '^[0-9a-f]{64}$'::text) AND ((media_type IS NULL) OR ((media_type)::text ~ '^[a-z0-9!#\$&^_.+-]+/[a-z0-9!#\$&^_.+-]+$'::text)) AND ((charset IS NULL) OR ((charset)::text ~ '^[a-z0-9!#\$&^_.+\-]{1,64}$'::text)) AND ((content_encoding)::text ~ '^[a-z0-9!#\$&^_.+\-]{1,64}$'::text))),
    CONSTRAINT crawl_fetch_results_outcome_shape CHECK ((((attempt_number >= 1) AND (attempt_number <= 10)) AND ((source_key_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((lease_token_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((request_method)::text = ANY ((ARRAY['GET'::character varying, 'HEAD'::character varying])::text[])) AND ((outcome)::text = ANY ((ARRAY['succeeded'::character varying, 'http_error'::character varying, 'rejected'::character varying, 'failed'::character varying, 'canceled'::character varying, 'throttled'::character varying])::text[])) AND ((failure_category IS NULL) OR ((failure_category)::text ~ '^[a-z][a-z0-9_]{0,63}$'::text)) AND ((http_status_code IS NULL) OR ((http_status_code >= 100) AND (http_status_code <= 599))) AND ((((outcome)::text = 'succeeded'::text) AND (failure_category IS NULL) AND ((http_status_code >= 200) AND (http_status_code <= 299))) OR (((outcome)::text = 'http_error'::text) AND (http_status_code IS NOT NULL) AND ((http_status_code < 200) OR (http_status_code > 299)) AND ((failure_category)::text = ('http_'::text || (http_status_code)::text))) OR (((outcome)::text = ANY ((ARRAY['rejected'::character varying, 'failed'::character varying, 'canceled'::character varying, 'throttled'::character varying])::text[])) AND (failure_category IS NOT NULL)))))
);


--
-- Name: crawl_fetch_results_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.crawl_fetch_results_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crawl_fetch_results_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.crawl_fetch_results_id_seq OWNED BY public.crawl_fetch_results.id;


--
-- Name: crawl_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crawl_links (
    id bigint NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid NOT NULL,
    environment_id uuid NOT NULL,
    scan_id uuid NOT NULL,
    page_snapshot_id bigint NOT NULL,
    source_crawl_url_id bigint NOT NULL,
    destination_crawl_url_id bigint,
    destination_url text NOT NULL,
    destination_url_digest character varying(64) NOT NULL,
    normalization_version integer NOT NULL,
    destination_host_digest character varying(64) NOT NULL,
    classification character varying(16) NOT NULL,
    scope_status character varying(16) NOT NULL,
    scope_reason character varying(64) NOT NULL,
    discovery_status character varying(24) NOT NULL,
    source_locator character varying(512) NOT NULL,
    rel_tokens character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    anchor_summary text,
    anchor_digest character varying(64) NOT NULL,
    nofollow boolean DEFAULT false NOT NULL,
    occurrence_count integer DEFAULT 1 NOT NULL,
    nofollow_count integer DEFAULT 0 NOT NULL,
    edge_digest character varying(64) NOT NULL,
    discovered_at timestamp(6) with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT crawl_links_destination_shape CHECK (((((classification)::text = 'external'::text) AND (destination_crawl_url_id IS NULL) AND ((scope_status)::text = 'denied'::text) AND ((discovery_status)::text = 'not_applicable'::text)) OR (((classification)::text = 'internal'::text) AND ((((scope_status)::text = 'allowed'::text) AND (destination_crawl_url_id IS NOT NULL) AND ((discovery_status)::text = 'linked'::text)) OR (((scope_status)::text = 'allowed'::text) AND (destination_crawl_url_id IS NULL) AND ((discovery_status)::text = 'not_admitted'::text)) OR (((scope_status)::text = 'denied'::text) AND (destination_crawl_url_id IS NULL) AND ((discovery_status)::text = 'not_applicable'::text)))))),
    CONSTRAINT crawl_links_evidence_shape CHECK ((((octet_length((source_locator)::text) >= 1) AND (octet_length((source_locator)::text) <= 512)) AND ((anchor_summary IS NULL) OR (octet_length(anchor_summary) <= 2048)) AND (cardinality(rel_tokens) <= 20) AND (pg_column_size(rel_tokens) <= 2048) AND (array_position(rel_tokens, NULL::character varying) IS NULL) AND (array_to_string(rel_tokens, ','::text) ~ '^([a-z][a-z0-9_-]{0,63})(,[a-z][a-z0-9_-]{0,63})*$|^$'::text) AND ((occurrence_count >= 1) AND (occurrence_count <= 5000)) AND ((nofollow_count >= 0) AND (nofollow_count <= occurrence_count)) AND (nofollow = (nofollow_count > 0)))),
    CONSTRAINT crawl_links_identity_shape CHECK ((((octet_length(destination_url) >= 1) AND (octet_length(destination_url) <= 8192)) AND ((destination_url_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((destination_host_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((edge_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((anchor_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((normalization_version >= 1) AND (normalization_version <= 100)) AND ((classification)::text = ANY ((ARRAY['internal'::character varying, 'external'::character varying])::text[])) AND ((scope_status)::text = ANY ((ARRAY['allowed'::character varying, 'denied'::character varying])::text[])) AND ((scope_reason)::text ~ '^[a-z][a-z0-9_]{0,63}$'::text)))
);


--
-- Name: crawl_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.crawl_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crawl_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.crawl_links_id_seq OWNED BY public.crawl_links.id;


--
-- Name: crawl_page_facts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crawl_page_facts (
    id bigint NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid NOT NULL,
    environment_id uuid NOT NULL,
    scan_id uuid NOT NULL,
    page_snapshot_id bigint NOT NULL,
    parser_version character varying(64) NOT NULL,
    content_sha256 character varying(64) NOT NULL,
    fact_digest character varying(64) NOT NULL,
    parse_status character varying(24) NOT NULL,
    parse_error_count integer DEFAULT 0 NOT NULL,
    element_count integer DEFAULT 0 NOT NULL,
    effective_base_url text,
    title_status character varying(24) NOT NULL,
    title_summary text,
    title_digest character varying(64),
    description_status character varying(24) NOT NULL,
    description_summary text,
    description_digest character varying(64),
    language_status character varying(24) NOT NULL,
    document_language character varying(64),
    fact_statuses jsonb DEFAULT '{}'::jsonb NOT NULL,
    meta_directives jsonb DEFAULT '[]'::jsonb NOT NULL,
    headings jsonb DEFAULT '[]'::jsonb NOT NULL,
    canonicals jsonb DEFAULT '[]'::jsonb NOT NULL,
    hreflangs jsonb DEFAULT '[]'::jsonb NOT NULL,
    images jsonb DEFAULT '[]'::jsonb NOT NULL,
    structured_data_blocks jsonb DEFAULT '[]'::jsonb NOT NULL,
    counts jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT crawl_page_facts_availability_shape CHECK (((((parse_status)::text = 'unavailable'::text) AND ((title_status)::text = 'unavailable'::text) AND ((description_status)::text = 'unavailable'::text) AND ((language_status)::text = 'unavailable'::text)) OR ((parse_status)::text = ANY ((ARRAY['parsed'::character varying, 'malformed'::character varying])::text[])))),
    CONSTRAINT crawl_page_facts_bounded_json CHECK (((jsonb_typeof(fact_statuses) = 'object'::text) AND (jsonb_typeof(meta_directives) = 'array'::text) AND (jsonb_typeof(headings) = 'array'::text) AND (jsonb_typeof(canonicals) = 'array'::text) AND (jsonb_typeof(hreflangs) = 'array'::text) AND (jsonb_typeof(images) = 'array'::text) AND (jsonb_typeof(structured_data_blocks) = 'array'::text) AND (jsonb_typeof(counts) = 'object'::text) AND (pg_column_size(fact_statuses) <= 4096) AND (pg_column_size(meta_directives) <= 65536) AND (pg_column_size(headings) <= 131072) AND (pg_column_size(canonicals) <= 32768) AND (pg_column_size(hreflangs) <= 65536) AND (pg_column_size(images) <= 262144) AND (pg_column_size(structured_data_blocks) <= 262144) AND (pg_column_size(counts) <= 4096) AND ((((((((pg_column_size(fact_statuses) + pg_column_size(meta_directives)) + pg_column_size(headings)) + pg_column_size(canonicals)) + pg_column_size(hreflangs)) + pg_column_size(images)) + pg_column_size(structured_data_blocks)) + pg_column_size(counts)) <= 786432))),
    CONSTRAINT crawl_page_facts_identity_shape CHECK ((((parser_version)::text ~ '^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$'::text) AND ((content_sha256)::text ~ '^[0-9a-f]{64}$'::text) AND ((fact_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((parse_status)::text = ANY ((ARRAY['parsed'::character varying, 'malformed'::character varying, 'unavailable'::character varying])::text[])) AND ((parse_error_count >= 0) AND (parse_error_count <= 20)) AND ((element_count >= 0) AND (element_count <= 50000)) AND ((effective_base_url IS NULL) OR ((octet_length(effective_base_url) >= 1) AND (octet_length(effective_base_url) <= 8192))))),
    CONSTRAINT crawl_page_facts_scalar_shape CHECK ((((title_status)::text = ANY ((ARRAY['present'::character varying, 'absent'::character varying, 'malformed'::character varying, 'unavailable'::character varying])::text[])) AND ((description_status)::text = ANY ((ARRAY['present'::character varying, 'absent'::character varying, 'malformed'::character varying, 'unavailable'::character varying])::text[])) AND ((language_status)::text = ANY ((ARRAY['present'::character varying, 'absent'::character varying, 'malformed'::character varying, 'unavailable'::character varying])::text[])) AND ((title_summary IS NULL) OR (octet_length(title_summary) <= 2048)) AND ((description_summary IS NULL) OR (octet_length(description_summary) <= 4096)) AND ((title_digest IS NULL) OR ((title_digest)::text ~ '^[0-9a-f]{64}$'::text)) AND ((description_digest IS NULL) OR ((description_digest)::text ~ '^[0-9a-f]{64}$'::text))))
);


--
-- Name: crawl_page_facts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.crawl_page_facts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crawl_page_facts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.crawl_page_facts_id_seq OWNED BY public.crawl_page_facts.id;


--
-- Name: crawl_page_renders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crawl_page_renders (
    id bigint NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid NOT NULL,
    environment_id uuid NOT NULL,
    scan_id uuid NOT NULL,
    page_snapshot_id bigint NOT NULL,
    page_fact_id bigint NOT NULL,
    state character varying(24) DEFAULT 'pending'::character varying NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    maximum_attempts integer DEFAULT 3 NOT NULL,
    worker_id character varying(128),
    lease_token_digest character varying(64),
    started_at timestamp(6) with time zone,
    lease_expires_at timestamp(6) with time zone,
    next_attempt_at timestamp(6) with time zone,
    finished_at timestamp(6) with time zone,
    failure_category character varying(64),
    screenshot_enabled boolean DEFAULT false NOT NULL,
    requested_url text NOT NULL,
    requested_url_digest character varying(64) NOT NULL,
    final_url text,
    final_url_digest character varying(64),
    rendered_dom_artifact_id uuid,
    screenshot_artifact_id uuid,
    rendered_dom_sha256 character varying(64),
    renderer_version character varying(64),
    ferrum_version character varying(64),
    browser_product character varying(128),
    browser_revision character varying(128),
    protocol_version character varying(64),
    duration_ms integer,
    request_count integer,
    response_bytes bigint,
    console_messages jsonb DEFAULT '[]'::jsonb NOT NULL,
    page_errors jsonb DEFAULT '[]'::jsonb NOT NULL,
    network_summary jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT crawl_page_renders_bounded_json CHECK (((jsonb_typeof(console_messages) = 'array'::text) AND (jsonb_array_length(console_messages) <= 100) AND (jsonb_typeof(page_errors) = 'array'::text) AND (jsonb_array_length(page_errors) <= 100) AND (jsonb_typeof(network_summary) = 'object'::text) AND (pg_column_size(console_messages) <= 32768) AND (pg_column_size(page_errors) <= 32768) AND (pg_column_size(network_summary) <= 65536))),
    CONSTRAINT crawl_page_renders_identity_shape CHECK ((((state)::text = ANY ((ARRAY['pending'::character varying, 'processing'::character varying, 'completed'::character varying, 'failed'::character varying, 'canceled'::character varying, 'skipped'::character varying])::text[])) AND ((attempts >= 0) AND (attempts <= maximum_attempts)) AND ((maximum_attempts >= 1) AND (maximum_attempts <= 10)) AND ((octet_length(requested_url) >= 1) AND (octet_length(requested_url) <= 8192)) AND ((requested_url_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((failure_category IS NULL) OR ((failure_category)::text ~ '^[a-z][a-z0-9_]{0,63}$'::text)))),
    CONSTRAINT crawl_page_renders_lifecycle_shape CHECK (((((state)::text = 'pending'::text) AND (worker_id IS NULL) AND (lease_token_digest IS NULL) AND (started_at IS NULL) AND (lease_expires_at IS NULL) AND (next_attempt_at IS NOT NULL) AND (finished_at IS NULL)) OR (((state)::text = 'processing'::text) AND ((worker_id)::text ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$'::text) AND ((lease_token_digest)::text ~ '^[0-9a-f]{64}$'::text) AND (started_at IS NOT NULL) AND (lease_expires_at > started_at) AND (next_attempt_at IS NULL) AND (finished_at IS NULL)) OR (((state)::text = ANY ((ARRAY['completed'::character varying, 'failed'::character varying, 'canceled'::character varying, 'skipped'::character varying])::text[])) AND (worker_id IS NULL) AND (lease_token_digest IS NULL) AND (started_at IS NULL) AND (lease_expires_at IS NULL) AND (next_attempt_at IS NULL) AND (finished_at IS NOT NULL)))),
    CONSTRAINT crawl_page_renders_result_shape CHECK (((((state)::text = 'completed'::text) AND (final_url IS NOT NULL) AND ((octet_length(final_url) >= 1) AND (octet_length(final_url) <= 8192)) AND ((final_url_digest)::text ~ '^[0-9a-f]{64}$'::text) AND (rendered_dom_artifact_id IS NOT NULL) AND ((rendered_dom_sha256)::text ~ '^[0-9a-f]{64}$'::text) AND ((renderer_version)::text ~ '^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$'::text) AND ((ferrum_version)::text ~ '^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$'::text) AND (browser_product IS NOT NULL) AND ((octet_length((browser_product)::text) >= 1) AND (octet_length((browser_product)::text) <= 128)) AND (browser_revision IS NOT NULL) AND ((octet_length((browser_revision)::text) >= 1) AND (octet_length((browser_revision)::text) <= 128)) AND ((protocol_version)::text ~ '^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$'::text) AND ((duration_ms >= 0) AND (duration_ms <= 300000)) AND ((request_count >= 1) AND (request_count <= 5000)) AND ((response_bytes >= 0) AND (response_bytes <= 524288000)) AND ((screenshot_enabled AND (screenshot_artifact_id IS NOT NULL)) OR ((NOT screenshot_enabled) AND (screenshot_artifact_id IS NULL)))) OR (((state)::text <> 'completed'::text) AND (final_url IS NULL) AND (final_url_digest IS NULL) AND (rendered_dom_artifact_id IS NULL) AND (screenshot_artifact_id IS NULL) AND (rendered_dom_sha256 IS NULL) AND (renderer_version IS NULL) AND (ferrum_version IS NULL) AND (browser_product IS NULL) AND (browser_revision IS NULL) AND (protocol_version IS NULL) AND (duration_ms IS NULL) AND (request_count IS NULL) AND (response_bytes IS NULL))))
);


--
-- Name: crawl_page_renders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.crawl_page_renders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crawl_page_renders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.crawl_page_renders_id_seq OWNED BY public.crawl_page_renders.id;


--
-- Name: crawl_page_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crawl_page_snapshots (
    id bigint NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid NOT NULL,
    environment_id uuid NOT NULL,
    scan_id uuid NOT NULL,
    crawl_url_id bigint NOT NULL,
    crawl_fetch_result_id bigint NOT NULL,
    artifact_id uuid NOT NULL,
    state character varying(24) DEFAULT 'pending'::character varying NOT NULL,
    extraction_attempts integer DEFAULT 0 NOT NULL,
    maximum_extraction_attempts integer DEFAULT 3 NOT NULL,
    extraction_worker_id character varying(128),
    extraction_token_digest character varying(64),
    extraction_started_at timestamp(6) with time zone,
    extraction_lease_expires_at timestamp(6) with time zone,
    next_attempt_at timestamp(6) with time zone,
    last_failure_category character varying(64),
    discovered_links_count integer DEFAULT 0 NOT NULL,
    discovery_parser_version character varying(64),
    finished_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT crawl_page_snapshots_lifecycle_shape CHECK (((((state)::text = 'pending'::text) AND (extraction_worker_id IS NULL) AND (extraction_token_digest IS NULL) AND (extraction_started_at IS NULL) AND (extraction_lease_expires_at IS NULL) AND (next_attempt_at IS NOT NULL) AND (finished_at IS NULL)) OR (((state)::text = 'processing'::text) AND ((extraction_worker_id)::text ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$'::text) AND ((extraction_token_digest)::text ~ '^[0-9a-f]{64}$'::text) AND (extraction_started_at IS NOT NULL) AND (extraction_lease_expires_at > extraction_started_at) AND (next_attempt_at IS NULL) AND (finished_at IS NULL)) OR (((state)::text = ANY ((ARRAY['completed'::character varying, 'failed'::character varying, 'skipped'::character varying])::text[])) AND (extraction_worker_id IS NULL) AND (extraction_token_digest IS NULL) AND (extraction_started_at IS NULL) AND (extraction_lease_expires_at IS NULL) AND (next_attempt_at IS NULL) AND (finished_at IS NOT NULL)))),
    CONSTRAINT crawl_page_snapshots_state_shape CHECK ((((state)::text = ANY ((ARRAY['pending'::character varying, 'processing'::character varying, 'completed'::character varying, 'failed'::character varying, 'skipped'::character varying])::text[])) AND ((extraction_attempts >= 0) AND (extraction_attempts <= maximum_extraction_attempts)) AND ((maximum_extraction_attempts >= 1) AND (maximum_extraction_attempts <= 10)) AND ((discovered_links_count >= 0) AND (discovered_links_count <= 100000)) AND ((last_failure_category IS NULL) OR ((last_failure_category)::text ~ '^[a-z][a-z0-9_]{0,63}$'::text)) AND ((discovery_parser_version IS NULL) OR ((discovery_parser_version)::text ~ '^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$'::text))))
);


--
-- Name: crawl_page_snapshots_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.crawl_page_snapshots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crawl_page_snapshots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.crawl_page_snapshots_id_seq OWNED BY public.crawl_page_snapshots.id;


--
-- Name: crawl_policy_sets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crawl_policy_sets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid NOT NULL,
    environment_id uuid NOT NULL,
    current_version integer DEFAULT 0 NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT crawl_policy_sets_current_version CHECK ((current_version >= 0))
);


--
-- Name: crawl_policy_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crawl_policy_snapshots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    scan_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid NOT NULL,
    environment_id uuid NOT NULL,
    crawl_policy_version_id uuid NOT NULL,
    policy_version integer NOT NULL,
    configuration jsonb NOT NULL,
    configuration_digest character varying(64) NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT crawl_policy_snapshots_bounded_configuration CHECK (((jsonb_typeof(configuration) = 'object'::text) AND (octet_length((configuration)::text) <= 32768))),
    CONSTRAINT crawl_policy_snapshots_digest CHECK (((configuration_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT crawl_policy_snapshots_positive_version CHECK ((policy_version > 0))
);


--
-- Name: crawl_policy_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crawl_policy_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    crawl_policy_set_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid NOT NULL,
    environment_id uuid NOT NULL,
    version integer NOT NULL,
    start_urls text[] DEFAULT '{}'::text[] NOT NULL,
    sitemap_urls text[] DEFAULT '{}'::text[] NOT NULL,
    include_patterns text[] DEFAULT '{}'::text[] NOT NULL,
    exclude_patterns text[] DEFAULT '{}'::text[] NOT NULL,
    max_urls integer NOT NULL,
    max_depth integer NOT NULL,
    query_handling character varying(24) NOT NULL,
    user_agent_suffix character varying(32),
    request_rate_per_second numeric(6,2) NOT NULL,
    max_concurrency integer NOT NULL,
    robots_behavior character varying(24) NOT NULL,
    rendering_sample_percent integer NOT NULL,
    max_rendered_pages integer NOT NULL,
    artifact_retention_days integer NOT NULL,
    created_by_membership_id uuid NOT NULL,
    change_kind character varying(24) NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    query_parameter_allowlist text[] DEFAULT '{}'::text[] NOT NULL,
    query_parameter_denylist text[] DEFAULT '{}'::text[] NOT NULL,
    CONSTRAINT crawl_policy_versions_allowlists CHECK ((((query_handling)::text = ANY (ARRAY[('ignore'::character varying)::text, ('tracking_only'::character varying)::text, ('all'::character varying)::text])) AND ((robots_behavior)::text = ANY (ARRAY[('respect'::character varying)::text, ('verified_owner_override'::character varying)::text])) AND ((change_kind)::text = ANY (ARRAY[('configured'::character varying)::text, ('reset'::character varying)::text, ('onboarding'::character varying)::text])))),
    CONSTRAINT crawl_policy_versions_bounded_lists CHECK (((cardinality(start_urls) >= 1) AND (cardinality(start_urls) <= 20) AND (cardinality(sitemap_urls) <= 20) AND (cardinality(include_patterns) <= 50) AND (cardinality(exclude_patterns) <= 50) AND (octet_length(array_to_string(start_urls, ''::text)) <= 40960) AND (octet_length(array_to_string(sitemap_urls, ''::text)) <= 40960) AND (octet_length(array_to_string(include_patterns, ''::text)) <= 12800) AND (octet_length(array_to_string(exclude_patterns, ''::text)) <= 12800))),
    CONSTRAINT crawl_policy_versions_crawl_bounds CHECK (((max_urls >= 1) AND (max_urls <= 1000000) AND ((max_depth >= 0) AND (max_depth <= 20)) AND ((request_rate_per_second >= 0.10) AND (request_rate_per_second <= 10.00)) AND ((max_concurrency >= 1) AND (max_concurrency <= 1000)))),
    CONSTRAINT crawl_policy_versions_positive_version CHECK ((version > 0)),
    CONSTRAINT crawl_policy_versions_query_parameter_lists CHECK (((cardinality(query_parameter_allowlist) <= 50) AND (cardinality(query_parameter_denylist) <= 50) AND (array_position(query_parameter_allowlist, NULL::text) IS NULL) AND (array_position(query_parameter_denylist, NULL::text) IS NULL) AND (octet_length(array_to_string(query_parameter_allowlist, ''::text)) <= 6400) AND (octet_length(array_to_string(query_parameter_denylist, ''::text)) <= 6400))),
    CONSTRAINT crawl_policy_versions_rendering_shape CHECK (((rendering_sample_percent >= 0) AND (rendering_sample_percent <= 100) AND (max_rendered_pages >= 0) AND (((rendering_sample_percent = 0) AND (max_rendered_pages = 0)) OR ((rendering_sample_percent > 0) AND (max_rendered_pages > 0))))),
    CONSTRAINT crawl_policy_versions_retention CHECK (((artifact_retention_days >= 0) AND (artifact_retention_days <= 36500))),
    CONSTRAINT crawl_policy_versions_user_agent_suffix CHECK (((user_agent_suffix IS NULL) OR ((user_agent_suffix)::text ~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,31}$'::text)))
);


--
-- Name: crawl_pressure_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crawl_pressure_states (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    scope_type character varying(24) NOT NULL,
    scope_key_digest character varying(64) NOT NULL,
    organization_id uuid,
    project_id uuid,
    property_id uuid,
    environment_id uuid,
    scan_id uuid,
    host_key_digest character varying(64),
    next_fetch_at timestamp(6) with time zone NOT NULL,
    backoff_until timestamp(6) with time zone,
    failure_streak integer DEFAULT 0 NOT NULL,
    disabled_at timestamp(6) with time zone,
    disabled_by_user_id uuid,
    disabled_reason character varying(64),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT crawl_pressure_states_backoff_shape CHECK (((failure_streak >= 0) AND (failure_streak <= 20) AND ((backoff_until IS NULL) OR ((scope_type)::text = 'host'::text)))),
    CONSTRAINT crawl_pressure_states_emergency_control_shape CHECK ((((disabled_at IS NULL) AND (disabled_by_user_id IS NULL) AND (disabled_reason IS NULL)) OR (((scope_type)::text = ANY (ARRAY[('global'::character varying)::text, ('host'::character varying)::text])) AND (disabled_at IS NOT NULL) AND (disabled_by_user_id IS NOT NULL) AND ((disabled_reason)::text ~ '^[a-z][a-z0-9_]{0,63}$'::text)))),
    CONSTRAINT crawl_pressure_states_identity_shape CHECK ((((scope_type)::text = ANY (ARRAY[('global'::character varying)::text, ('organization'::character varying)::text, ('scan'::character varying)::text, ('host'::character varying)::text])) AND ((scope_key_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((host_key_digest IS NULL) OR ((host_key_digest)::text ~ '^[0-9a-f]{64}$'::text)))),
    CONSTRAINT crawl_pressure_states_scope_shape CHECK (((((scope_type)::text = 'global'::text) AND (organization_id IS NULL) AND (project_id IS NULL) AND (property_id IS NULL) AND (environment_id IS NULL) AND (scan_id IS NULL) AND (host_key_digest IS NULL)) OR (((scope_type)::text = 'organization'::text) AND (organization_id IS NOT NULL) AND (project_id IS NULL) AND (property_id IS NULL) AND (environment_id IS NULL) AND (scan_id IS NULL) AND (host_key_digest IS NULL)) OR (((scope_type)::text = 'scan'::text) AND (organization_id IS NOT NULL) AND (project_id IS NOT NULL) AND (property_id IS NOT NULL) AND (environment_id IS NOT NULL) AND (scan_id IS NOT NULL) AND (host_key_digest IS NULL)) OR (((scope_type)::text = 'host'::text) AND (organization_id IS NULL) AND (project_id IS NULL) AND (property_id IS NULL) AND (environment_id IS NULL) AND (scan_id IS NULL) AND (host_key_digest IS NOT NULL))))
);


--
-- Name: crawl_rendered_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crawl_rendered_links (
    id bigint NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid NOT NULL,
    environment_id uuid NOT NULL,
    scan_id uuid NOT NULL,
    page_render_id bigint NOT NULL,
    destination_url text NOT NULL,
    destination_url_digest character varying(64) NOT NULL,
    destination_host_digest character varying(64) NOT NULL,
    normalization_version integer NOT NULL,
    classification character varying(16) NOT NULL,
    scope_status character varying(16) NOT NULL,
    scope_reason character varying(64) NOT NULL,
    source_locator character varying(512) NOT NULL,
    rel_tokens character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    anchor_summary text,
    anchor_digest character varying(64) NOT NULL,
    occurrence_count integer NOT NULL,
    nofollow_count integer NOT NULL,
    edge_digest character varying(64) NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT crawl_rendered_links_shape CHECK ((((octet_length(destination_url) >= 1) AND (octet_length(destination_url) <= 8192)) AND ((destination_url_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((destination_host_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((edge_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((anchor_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((normalization_version >= 1) AND (normalization_version <= 100)) AND ((classification)::text = ANY ((ARRAY['internal'::character varying, 'external'::character varying])::text[])) AND ((scope_status)::text = ANY ((ARRAY['allowed'::character varying, 'denied'::character varying])::text[])) AND ((scope_reason)::text ~ '^[a-z][a-z0-9_]{0,63}$'::text) AND ((octet_length((source_locator)::text) >= 1) AND (octet_length((source_locator)::text) <= 512)) AND ((anchor_summary IS NULL) OR (octet_length(anchor_summary) <= 2048)) AND (cardinality(rel_tokens) <= 20) AND (pg_column_size(rel_tokens) <= 2048) AND (array_position(rel_tokens, NULL::character varying) IS NULL) AND ((occurrence_count >= 1) AND (occurrence_count <= 5000)) AND ((nofollow_count >= 0) AND (nofollow_count <= occurrence_count))))
);


--
-- Name: crawl_rendered_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.crawl_rendered_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crawl_rendered_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.crawl_rendered_links_id_seq OWNED BY public.crawl_rendered_links.id;


--
-- Name: crawl_rendered_page_facts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crawl_rendered_page_facts (
    id bigint NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid NOT NULL,
    environment_id uuid NOT NULL,
    scan_id uuid NOT NULL,
    page_render_id bigint NOT NULL,
    parser_version character varying(64) NOT NULL,
    content_sha256 character varying(64) NOT NULL,
    fact_digest character varying(64) NOT NULL,
    parse_status character varying(24) NOT NULL,
    facts jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT crawl_rendered_page_facts_shape CHECK ((((parser_version)::text ~ '^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$'::text) AND ((content_sha256)::text ~ '^[0-9a-f]{64}$'::text) AND ((fact_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((parse_status)::text = ANY ((ARRAY['parsed'::character varying, 'malformed'::character varying])::text[])) AND (jsonb_typeof(facts) = 'object'::text) AND (pg_column_size(facts) <= 786432)))
);


--
-- Name: crawl_rendered_page_facts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.crawl_rendered_page_facts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crawl_rendered_page_facts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.crawl_rendered_page_facts_id_seq OWNED BY public.crawl_rendered_page_facts.id;


--
-- Name: crawl_robots_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crawl_robots_snapshots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid NOT NULL,
    environment_id uuid NOT NULL,
    scan_id uuid NOT NULL,
    origin text NOT NULL,
    origin_digest character varying(64) NOT NULL,
    source_url text NOT NULL,
    final_url text,
    retrieval_status character varying(24) NOT NULL,
    http_status integer,
    retrieved_at timestamp(6) with time zone NOT NULL,
    artifact_sha256 character varying(64),
    parser_version integer NOT NULL,
    redirect_count integer DEFAULT 0 NOT NULL,
    error_code character varying(64),
    groups jsonb DEFAULT '[]'::jsonb NOT NULL,
    sitemap_urls text[] DEFAULT '{}'::text[] NOT NULL,
    warnings jsonb DEFAULT '[]'::jsonb NOT NULL,
    malformed boolean DEFAULT false NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT crawl_robots_snapshots_http_shape CHECK (((((retrieval_status)::text <> 'fetched'::text) OR ((http_status >= 200) AND (http_status <= 299) AND (artifact_sha256 IS NOT NULL) AND (final_url IS NOT NULL))) AND (((retrieval_status)::text <> 'unavailable'::text) OR ((http_status >= 400) AND (http_status <= 499))))),
    CONSTRAINT crawl_robots_snapshots_identity_shape CHECK (((octet_length(origin) >= 1) AND (octet_length(origin) <= 2048) AND ((octet_length(source_url) >= 1) AND (octet_length(source_url) <= 2048)) AND ((final_url IS NULL) OR ((octet_length(final_url) >= 1) AND (octet_length(final_url) <= 2048))) AND ((origin_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((artifact_sha256 IS NULL) OR ((artifact_sha256)::text ~ '^[0-9a-f]{64}$'::text)))),
    CONSTRAINT crawl_robots_snapshots_payload_shape CHECK (((jsonb_typeof(groups) = 'array'::text) AND (pg_column_size(groups) <= 1048576) AND (jsonb_typeof(warnings) = 'array'::text) AND (pg_column_size(warnings) <= 1048576) AND (cardinality(sitemap_urls) <= 100) AND (array_position(sitemap_urls, NULL::text) IS NULL) AND (octet_length(array_to_string(sitemap_urls, ''::text)) <= 204800))),
    CONSTRAINT crawl_robots_snapshots_result_shape CHECK ((((retrieval_status)::text = ANY (ARRAY[('fetched'::character varying)::text, ('unavailable'::character varying)::text, ('unreachable'::character varying)::text, ('oversized'::character varying)::text, ('malformed'::character varying)::text])) AND (parser_version > 0) AND ((redirect_count >= 0) AND (redirect_count <= 5)) AND ((http_status IS NULL) OR ((http_status >= 100) AND (http_status <= 599))) AND ((error_code IS NULL) OR ((error_code)::text ~ '^[a-z][a-z0-9_]{0,63}$'::text))))
);


--
-- Name: crawl_scan_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crawl_scan_executions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid NOT NULL,
    environment_id uuid NOT NULL,
    scan_id uuid NOT NULL,
    state character varying(32) DEFAULT 'pending'::character varying NOT NULL,
    initialization_attempts integer DEFAULT 0 NOT NULL,
    maximum_initialization_attempts integer DEFAULT 3 NOT NULL,
    initialization_worker_id character varying(128),
    initialization_token_digest character varying(64),
    initialization_started_at timestamp(6) with time zone,
    initialization_lease_expires_at timestamp(6) with time zone,
    initialized_at timestamp(6) with time zone,
    last_failure_category character varying(64),
    last_live_update_at timestamp(6) with time zone,
    finished_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT crawl_scan_executions_lifecycle_shape CHECK (((((state)::text = 'initializing'::text) = ((initialization_worker_id IS NOT NULL) AND ((initialization_worker_id)::text ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$'::text) AND ((initialization_token_digest)::text ~ '^[0-9a-f]{64}$'::text) AND (initialization_started_at IS NOT NULL) AND (initialization_lease_expires_at > initialization_started_at))) AND (((state)::text <> ALL ((ARRAY['ready'::character varying, 'completed'::character varying, 'partially_completed'::character varying])::text[])) OR (initialized_at IS NOT NULL)) AND (((state)::text <> ALL ((ARRAY['completed'::character varying, 'partially_completed'::character varying, 'canceled'::character varying, 'failed'::character varying])::text[])) OR (finished_at IS NOT NULL)))),
    CONSTRAINT crawl_scan_executions_state_shape CHECK ((((state)::text = ANY ((ARRAY['pending'::character varying, 'initializing'::character varying, 'ready'::character varying, 'completed'::character varying, 'partially_completed'::character varying, 'canceled'::character varying, 'failed'::character varying])::text[])) AND ((initialization_attempts >= 0) AND (initialization_attempts <= maximum_initialization_attempts)) AND ((maximum_initialization_attempts >= 1) AND (maximum_initialization_attempts <= 10)) AND ((last_failure_category IS NULL) OR ((last_failure_category)::text ~ '^[a-z][a-z0-9_]{0,63}$'::text))))
);


--
-- Name: crawl_scan_usage_operations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crawl_scan_usage_operations (
    id bigint NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid NOT NULL,
    environment_id uuid NOT NULL,
    scan_id uuid NOT NULL,
    usage_quota_allocation_id uuid,
    usage_event_id bigint,
    operation_kind character varying(32) NOT NULL,
    meter_key character varying(96),
    meter_rate_version integer,
    applied_weight numeric(18,6),
    reserved_credits numeric(30,6) DEFAULT 0.0 NOT NULL,
    source_key_digest character varying(64) NOT NULL,
    request_checksum character varying(64) NOT NULL,
    completion_checksum character varying(64),
    state character varying(24) NOT NULL,
    outcome character varying(24),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    attempted_at timestamp(6) with time zone NOT NULL,
    finished_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT crawl_scan_usage_operations_digest_shape CHECK ((((source_key_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((request_checksum)::text ~ '^[0-9a-f]{64}$'::text) AND ((completion_checksum IS NULL) OR ((completion_checksum)::text ~ '^[0-9a-f]{64}$'::text)))),
    CONSTRAINT crawl_scan_usage_operations_kind_allowlist CHECK (((operation_kind)::text = ANY ((ARRAY['http_fetch'::character varying, 'rendered_page'::character varying, 'lighthouse_page'::character varying, 'artifact'::character varying])::text[]))),
    CONSTRAINT crawl_scan_usage_operations_lifecycle_shape CHECK (((((state)::text = 'reserved'::text) AND (outcome IS NULL) AND (completion_checksum IS NULL) AND (usage_event_id IS NULL) AND (finished_at IS NULL)) OR (((state)::text = 'billed'::text) AND ((operation_kind)::text <> 'artifact'::text) AND ((outcome)::text = 'accepted'::text) AND (completion_checksum IS NOT NULL) AND (usage_event_id IS NOT NULL) AND (finished_at IS NOT NULL)) OR (((state)::text = 'not_billable'::text) AND (completion_checksum IS NOT NULL) AND (usage_event_id IS NULL) AND (outcome IS NOT NULL) AND (finished_at IS NOT NULL) AND (((operation_kind)::text = 'artifact'::text) OR ((outcome)::text <> 'accepted'::text))))),
    CONSTRAINT crawl_scan_usage_operations_metadata_shape CHECK (((jsonb_typeof(metadata) = 'object'::text) AND (pg_column_size(metadata) <= 4096))),
    CONSTRAINT crawl_scan_usage_operations_meter_shape CHECK (((((operation_kind)::text = 'artifact'::text) AND (meter_key IS NULL) AND (meter_rate_version IS NULL) AND (applied_weight IS NULL) AND (reserved_credits = (0)::numeric) AND (usage_quota_allocation_id IS NULL)) OR (((operation_kind)::text <> 'artifact'::text) AND (meter_key IS NOT NULL) AND (meter_rate_version > 0) AND (applied_weight > (0)::numeric) AND (reserved_credits = applied_weight) AND (usage_quota_allocation_id IS NOT NULL)))),
    CONSTRAINT crawl_scan_usage_operations_state_allowlist CHECK ((((state)::text = ANY ((ARRAY['reserved'::character varying, 'billed'::character varying, 'not_billable'::character varying])::text[])) AND ((outcome IS NULL) OR ((outcome)::text = ANY ((ARRAY['accepted'::character varying, 'failed'::character varying, 'canceled'::character varying, 'rejected'::character varying, 'abandoned'::character varying])::text[])))))
);


--
-- Name: crawl_scan_usage_operations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.crawl_scan_usage_operations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crawl_scan_usage_operations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.crawl_scan_usage_operations_id_seq OWNED BY public.crawl_scan_usage_operations.id;


--
-- Name: crawl_sitemap_discoveries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crawl_sitemap_discoveries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid NOT NULL,
    environment_id uuid NOT NULL,
    scan_id uuid NOT NULL,
    status character varying(32) DEFAULT 'running'::character varying NOT NULL,
    documents_discovered_count bigint DEFAULT 0 NOT NULL,
    documents_processed_count bigint DEFAULT 0 NOT NULL,
    documents_succeeded_count bigint DEFAULT 0 NOT NULL,
    documents_failed_count bigint DEFAULT 0 NOT NULL,
    entries_observed_count bigint DEFAULT 0 NOT NULL,
    entries_in_scope_count bigint DEFAULT 0 NOT NULL,
    entries_out_of_scope_count bigint DEFAULT 0 NOT NULL,
    entries_invalid_count bigint DEFAULT 0 NOT NULL,
    frontier_inserted_count bigint DEFAULT 0 NOT NULL,
    fetch_attempt_count bigint DEFAULT 0 NOT NULL,
    metered_fetch_count bigint DEFAULT 0 NOT NULL,
    compressed_bytes_count bigint DEFAULT 0 NOT NULL,
    decompressed_bytes_count bigint DEFAULT 0 NOT NULL,
    warning_count bigint DEFAULT 0 NOT NULL,
    warning_codes text[] DEFAULT '{}'::text[] NOT NULL,
    started_at timestamp(6) with time zone NOT NULL,
    finished_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT crawl_sitemap_discoveries_counters CHECK (((documents_discovered_count >= 0) AND (documents_processed_count >= 0) AND (documents_succeeded_count >= 0) AND (documents_failed_count >= 0) AND (entries_observed_count >= 0) AND (entries_in_scope_count >= 0) AND (entries_out_of_scope_count >= 0) AND (entries_invalid_count >= 0) AND (frontier_inserted_count >= 0) AND (fetch_attempt_count >= 0) AND (metered_fetch_count >= 0) AND (compressed_bytes_count >= 0) AND (decompressed_bytes_count >= 0) AND (warning_count >= 0) AND (documents_processed_count = (documents_succeeded_count + documents_failed_count)) AND (entries_observed_count = ((entries_in_scope_count + entries_out_of_scope_count) + entries_invalid_count)) AND (frontier_inserted_count <= entries_in_scope_count) AND (metered_fetch_count <= fetch_attempt_count))),
    CONSTRAINT crawl_sitemap_discoveries_lifecycle CHECK ((((status)::text = ANY (ARRAY[('running'::character varying)::text, ('completed'::character varying)::text, ('partially_completed'::character varying)::text, ('failed'::character varying)::text])) AND ((((status)::text = 'running'::text) AND (finished_at IS NULL)) OR (((status)::text <> 'running'::text) AND (finished_at IS NOT NULL) AND (finished_at >= started_at))))),
    CONSTRAINT crawl_sitemap_discoveries_warnings CHECK (((cardinality(warning_codes) <= 1000) AND (array_position(warning_codes, NULL::text) IS NULL) AND (octet_length(array_to_string(warning_codes, ''::text)) <= 64000)))
);


--
-- Name: crawl_sitemap_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crawl_sitemap_entries (
    id bigint NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid NOT NULL,
    environment_id uuid NOT NULL,
    scan_id uuid NOT NULL,
    sitemap_file_id uuid NOT NULL,
    entry_index integer NOT NULL,
    entry_kind character varying(16) NOT NULL,
    location_url text NOT NULL,
    location_digest character varying(64) NOT NULL,
    normalization_version integer NOT NULL,
    scope_status character varying(24) NOT NULL,
    scope_reason character varying(64) NOT NULL,
    relationship_status character varying(32) NOT NULL,
    lastmod_text text,
    lastmod_at timestamp(6) with time zone,
    lastmod_precision character varying(16),
    crawl_url_id bigint,
    child_sitemap_file_id uuid,
    created_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT crawl_sitemap_entries_identity CHECK (((entry_index > 0) AND ((entry_kind)::text = ANY (ARRAY[('page'::character varying)::text, ('sitemap'::character varying)::text])) AND ((octet_length(location_url) >= 1) AND (octet_length(location_url) <= 8192)) AND ((location_digest)::text ~ '^[0-9a-f]{64}$'::text) AND (normalization_version > 0))),
    CONSTRAINT crawl_sitemap_entries_lastmod CHECK ((((lastmod_text IS NULL) AND (lastmod_at IS NULL) AND (lastmod_precision IS NULL)) OR ((lastmod_text IS NOT NULL) AND ((octet_length(lastmod_text) >= 1) AND (octet_length(lastmod_text) <= 64)) AND ((lastmod_precision)::text = ANY (ARRAY[('date'::character varying)::text, ('datetime'::character varying)::text, ('invalid'::character varying)::text])) AND ((((lastmod_precision)::text = 'invalid'::text) AND (lastmod_at IS NULL)) OR (((lastmod_precision)::text <> 'invalid'::text) AND (lastmod_at IS NOT NULL)))))),
    CONSTRAINT crawl_sitemap_entries_outcome CHECK ((((scope_status)::text = ANY (ARRAY[('in_scope'::character varying)::text, ('out_of_scope'::character varying)::text])) AND ((scope_reason)::text ~ '^[a-z][a-z0-9_]{0,63}$'::text) AND ((relationship_status)::text = ANY (ARRAY[('frontier_inserted'::character varying)::text, ('frontier_duplicate'::character varying)::text, ('frontier_limit'::character varying)::text, ('queued'::character varying)::text, ('duplicate'::character varying)::text, ('circular'::character varying)::text, ('depth_rejected'::character varying)::text, ('document_limit'::character varying)::text, ('out_of_scope'::character varying)::text])) AND (((scope_status)::text <> 'out_of_scope'::text) OR ((relationship_status)::text = 'out_of_scope'::text)) AND ((crawl_url_id IS NULL) OR ((entry_kind)::text = 'page'::text)) AND ((child_sitemap_file_id IS NULL) OR ((entry_kind)::text = 'sitemap'::text)) AND (((relationship_status)::text <> 'frontier_inserted'::text) OR (crawl_url_id IS NOT NULL)) AND (((relationship_status)::text <> ALL (ARRAY[('queued'::character varying)::text, ('duplicate'::character varying)::text, ('circular'::character varying)::text])) OR (child_sitemap_file_id IS NOT NULL))))
);


--
-- Name: crawl_sitemap_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.crawl_sitemap_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crawl_sitemap_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.crawl_sitemap_entries_id_seq OWNED BY public.crawl_sitemap_entries.id;


--
-- Name: crawl_sitemap_files; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crawl_sitemap_files (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid NOT NULL,
    environment_id uuid NOT NULL,
    scan_id uuid NOT NULL,
    sitemap_discovery_id uuid NOT NULL,
    parent_sitemap_file_id uuid,
    url text NOT NULL,
    url_digest character varying(64) NOT NULL,
    source character varying(24) NOT NULL,
    index_depth integer NOT NULL,
    status character varying(24) DEFAULT 'pending'::character varying NOT NULL,
    document_kind character varying(24),
    final_url text,
    http_status integer,
    retrieved_at timestamp(6) with time zone,
    artifact_sha256 character varying(64),
    content_type character varying(128),
    gzip boolean,
    compressed_bytes bigint,
    decompressed_bytes bigint,
    redirect_count integer,
    parser_version integer,
    entry_count bigint DEFAULT 0 NOT NULL,
    entries_in_scope_count bigint DEFAULT 0 NOT NULL,
    entries_out_of_scope_count bigint DEFAULT 0 NOT NULL,
    entries_invalid_count bigint DEFAULT 0 NOT NULL,
    child_count bigint DEFAULT 0 NOT NULL,
    warning_count integer DEFAULT 0 NOT NULL,
    warnings jsonb DEFAULT '[]'::jsonb NOT NULL,
    error_code character varying(64),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT crawl_sitemap_files_counters CHECK (((entry_count >= 0) AND (entries_in_scope_count >= 0) AND (entries_out_of_scope_count >= 0) AND (entries_invalid_count >= 0) AND (entry_count = ((entries_in_scope_count + entries_out_of_scope_count) + entries_invalid_count)) AND (child_count >= 0) AND ((warning_count >= 0) AND (warning_count <= 1000)) AND (jsonb_typeof(warnings) = 'array'::text) AND (pg_column_size(warnings) <= 131072))),
    CONSTRAINT crawl_sitemap_files_identity CHECK (((octet_length(url) >= 1) AND (octet_length(url) <= 8192) AND ((url_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((final_url IS NULL) OR ((octet_length(final_url) >= 1) AND (octet_length(final_url) <= 8192))) AND ((artifact_sha256 IS NULL) OR ((artifact_sha256)::text ~ '^[0-9a-f]{64}$'::text)))),
    CONSTRAINT crawl_sitemap_files_provenance CHECK ((((source)::text = ANY (ARRAY[('configured'::character varying)::text, ('robots'::character varying)::text, ('well_known'::character varying)::text, ('sitemap_index'::character varying)::text])) AND ((index_depth >= 0) AND (index_depth <= 10)) AND ((parent_sitemap_file_id IS NULL) OR (parent_sitemap_file_id <> id)))),
    CONSTRAINT crawl_sitemap_files_result CHECK ((((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('fetched'::character varying)::text, ('unavailable'::character varying)::text, ('unreachable'::character varying)::text, ('oversized'::character varying)::text, ('malformed'::character varying)::text, ('rejected'::character varying)::text])) AND ((document_kind IS NULL) OR ((document_kind)::text = ANY (ARRAY[('urlset'::character varying)::text, ('sitemap_index'::character varying)::text]))) AND ((http_status IS NULL) OR ((http_status >= 100) AND (http_status <= 599))) AND ((content_type IS NULL) OR ((octet_length((content_type)::text) >= 1) AND (octet_length((content_type)::text) <= 128))) AND ((redirect_count IS NULL) OR ((redirect_count >= 0) AND (redirect_count <= 5))) AND ((parser_version IS NULL) OR (parser_version > 0)) AND ((compressed_bytes IS NULL) OR (compressed_bytes >= 0)) AND ((decompressed_bytes IS NULL) OR (decompressed_bytes >= 0)) AND ((error_code IS NULL) OR ((error_code)::text ~ '^[a-z][a-z0-9_]{0,63}$'::text)) AND (((status)::text <> 'pending'::text) OR ((retrieved_at IS NULL) AND (artifact_sha256 IS NULL) AND (http_status IS NULL) AND (final_url IS NULL) AND (document_kind IS NULL) AND (compressed_bytes IS NULL) AND (decompressed_bytes IS NULL) AND (redirect_count IS NULL) AND (parser_version IS NULL) AND (error_code IS NULL))) AND (((status)::text <> 'fetched'::text) OR ((http_status >= 200) AND (http_status <= 299) AND (retrieved_at IS NOT NULL) AND (artifact_sha256 IS NOT NULL) AND (final_url IS NOT NULL) AND (document_kind IS NOT NULL) AND (parser_version IS NOT NULL))) AND (((status)::text <> 'rejected'::text) OR ((retrieved_at IS NULL) AND (http_status IS NULL) AND (artifact_sha256 IS NULL) AND (error_code IS NOT NULL)))))
);


--
-- Name: crawl_urls; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crawl_urls (
    id bigint NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid NOT NULL,
    environment_id uuid NOT NULL,
    scan_id uuid NOT NULL,
    normalized_url_digest character varying(64) NOT NULL,
    normalization_version integer NOT NULL,
    normalized_url text NOT NULL,
    host_digest character varying(64) NOT NULL,
    depth integer NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    discovery_source character varying(24) NOT NULL,
    discovered_from_id bigint,
    state character varying(24) DEFAULT 'pending'::character varying NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    maximum_attempts integer NOT NULL,
    leased_by character varying(128),
    lease_token_digest character varying(64),
    leased_at timestamp(6) with time zone,
    lease_expires_at timestamp(6) with time zone,
    next_attempt_at timestamp(6) with time zone,
    last_lease_token_digest character varying(64),
    last_lease_outcome character varying(24),
    last_failure_category character varying(64),
    fetch_result_id bigint,
    http_status_code integer,
    completed_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    fetch_url text NOT NULL,
    CONSTRAINT crawl_urls_attempt_shape CHECK ((((state)::text = ANY (ARRAY[('pending'::character varying)::text, ('leased'::character varying)::text, ('succeeded'::character varying)::text, ('rejected'::character varying)::text, ('failed'::character varying)::text, ('exhausted'::character varying)::text])) AND ((attempts >= 0) AND (attempts <= maximum_attempts)) AND ((maximum_attempts >= 1) AND (maximum_attempts <= 10)) AND (((state)::text <> 'pending'::text) OR (attempts < maximum_attempts)))),
    CONSTRAINT crawl_urls_discovery_shape CHECK (((depth >= 0) AND (depth <= 100) AND ((priority >= '-1000000'::integer) AND (priority <= 1000000)) AND ((discovery_source)::text = ANY (ARRAY[('seed'::character varying)::text, ('sitemap'::character varying)::text, ('link'::character varying)::text, ('redirect'::character varying)::text, ('canonical'::character varying)::text])) AND ((discovered_from_id IS NULL) OR (discovered_from_id <> id)))),
    CONSTRAINT crawl_urls_fetch_url_shape CHECK (((fetch_url IS NOT NULL) AND ((octet_length(fetch_url) >= 1) AND (octet_length(fetch_url) <= 8192)))),
    CONSTRAINT crawl_urls_last_outcome_shape CHECK (((((last_lease_token_digest IS NULL) AND (last_lease_outcome IS NULL)) OR (((last_lease_token_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((last_lease_outcome)::text = ANY (ARRAY[('retry'::character varying)::text, ('stale_recovered'::character varying)::text, ('succeeded'::character varying)::text, ('rejected'::character varying)::text, ('failed'::character varying)::text, ('exhausted'::character varying)::text])))) AND ((last_failure_category IS NULL) OR ((last_failure_category)::text ~ '^[a-z][a-z0-9_]{0,63}$'::text)))),
    CONSTRAINT crawl_urls_lifecycle_shape CHECK (((((state)::text = 'pending'::text) AND (leased_by IS NULL) AND (lease_token_digest IS NULL) AND (leased_at IS NULL) AND (lease_expires_at IS NULL) AND (completed_at IS NULL) AND (next_attempt_at IS NOT NULL)) OR (((state)::text = 'leased'::text) AND ((leased_by)::text ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$'::text) AND ((lease_token_digest)::text ~ '^[0-9a-f]{64}$'::text) AND (leased_at IS NOT NULL) AND (lease_expires_at > leased_at) AND (completed_at IS NULL) AND (next_attempt_at IS NULL)) OR (((state)::text = ANY (ARRAY[('succeeded'::character varying)::text, ('rejected'::character varying)::text, ('failed'::character varying)::text, ('exhausted'::character varying)::text])) AND (leased_by IS NULL) AND (lease_token_digest IS NULL) AND (leased_at IS NULL) AND (lease_expires_at IS NULL) AND (next_attempt_at IS NULL) AND (completed_at IS NOT NULL) AND (last_lease_token_digest IS NOT NULL) AND ((last_lease_outcome)::text = (state)::text)))),
    CONSTRAINT crawl_urls_normalized_identity_shape CHECK (((normalization_version > 0) AND ((normalized_url_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((host_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((octet_length(normalized_url) >= 1) AND (octet_length(normalized_url) <= 8192)))),
    CONSTRAINT crawl_urls_result_shape CHECK (((((fetch_result_id IS NULL) AND (http_status_code IS NULL)) OR ((fetch_result_id > 0) AND ((http_status_code IS NULL) OR ((http_status_code >= 100) AND (http_status_code <= 599))))) AND (((state)::text <> 'succeeded'::text) OR (fetch_result_id IS NOT NULL))))
);


--
-- Name: crawl_urls_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.crawl_urls_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crawl_urls_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.crawl_urls_id_seq OWNED BY public.crawl_urls.id;


--
-- Name: domain_verification_attempts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.domain_verification_attempts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid NOT NULL,
    environment_id uuid NOT NULL,
    domain_verification_id uuid NOT NULL,
    sequence integer NOT NULL,
    outcome character varying(24) NOT NULL,
    failure_category character varying(48),
    evidence jsonb DEFAULT '{}'::jsonb NOT NULL,
    attempted_at timestamp(6) with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT domain_verification_attempts_evidence_shape CHECK (((jsonb_typeof(evidence) = 'object'::text) AND (octet_length((evidence)::text) <= 4096))),
    CONSTRAINT domain_verification_attempts_failure_category_allowlist CHECK (((failure_category IS NULL) OR ((failure_category)::text = ANY (ARRAY[('proof_missing'::character varying)::text, ('proof_mismatch'::character varying)::text, ('provider_unavailable'::character varying)::text, ('provider_unauthorized'::character varying)::text, ('unsafe_destination'::character varying)::text, ('malformed_response'::character varying)::text, ('attempt_limit'::character varying)::text, ('dns_nxdomain'::character varying)::text, ('dns_no_record'::character varying)::text, ('dns_propagating'::character varying)::text, ('dns_timeout'::character varying)::text, ('dns_transient_failure'::character varying)::text, ('dns_multiple_records'::character varying)::text, ('dns_response_limit'::character varying)::text, ('dns_cname_limit'::character varying)::text, ('dns_delegation_limit'::character varying)::text, ('http_dns_failure'::character varying)::text, ('http_timeout'::character varying)::text, ('http_transport_failure'::character varying)::text, ('http_redirect_rejected'::character varying)::text, ('http_redirect_limit'::character varying)::text, ('http_response_too_large'::character varying)::text, ('http_content_type_rejected'::character varying)::text, ('duplicate_meta'::character varying)::text, ('provider_scope_revoked'::character varying)::text, ('provider_property_inaccessible'::character varying)::text, ('provider_outage'::character varying)::text, ('provider_ambiguous_match'::character varying)::text, ('provider_no_match'::character varying)::text, ('provider_insufficient_permission'::character varying)::text, ('provider_connection_changed'::character varying)::text])))),
    CONSTRAINT domain_verification_attempts_failure_shape CHECK (((((outcome)::text = 'verified'::text) AND (failure_category IS NULL)) OR (((outcome)::text = 'failed'::text) AND (failure_category IS NOT NULL)))),
    CONSTRAINT domain_verification_attempts_outcome CHECK (((sequence > 0) AND ((outcome)::text = ANY (ARRAY[('verified'::character varying)::text, ('failed'::character varying)::text]))))
);


--
-- Name: domain_verifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.domain_verifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid NOT NULL,
    environment_id uuid NOT NULL,
    issued_by_membership_id uuid NOT NULL,
    method character varying(32) NOT NULL,
    challenge_digest character varying(64) NOT NULL,
    expected_location text NOT NULL,
    bound_origin text NOT NULL,
    state character varying(24) DEFAULT 'pending'::character varying NOT NULL,
    attempt_count integer DEFAULT 0 NOT NULL,
    attempted_at timestamp(6) with time zone,
    verified_at timestamp(6) with time zone,
    failed_at timestamp(6) with time zone,
    expired_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    expires_at timestamp(6) with time zone NOT NULL,
    failure_category character varying(48),
    evidence jsonb DEFAULT '{}'::jsonb NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    integration_connection_id uuid,
    provider_property_identifier text,
    provider_property_type character varying(24),
    provider_permission_level character varying(32),
    provider_checked_at timestamp(6) with time zone,
    connection_revision integer,
    CONSTRAINT domain_verifications_attempt_shape CHECK (((attempt_count >= 0) AND (((attempt_count = 0) AND (attempted_at IS NULL)) OR ((attempt_count > 0) AND (attempted_at IS NOT NULL))))),
    CONSTRAINT domain_verifications_bounded_binding CHECK (((char_length(expected_location) >= 1) AND (char_length(expected_location) <= 2048) AND ((char_length(bound_origin) >= 8) AND (char_length(bound_origin) <= 2048)))),
    CONSTRAINT domain_verifications_digest_format CHECK (((challenge_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT domain_verifications_evidence_shape CHECK (((jsonb_typeof(evidence) = 'object'::text) AND (octet_length((evidence)::text) <= 4096))),
    CONSTRAINT domain_verifications_expiry_order CHECK ((expires_at > created_at)),
    CONSTRAINT domain_verifications_failure_category_allowlist CHECK (((failure_category IS NULL) OR ((failure_category)::text = ANY (ARRAY[('proof_missing'::character varying)::text, ('proof_mismatch'::character varying)::text, ('provider_unavailable'::character varying)::text, ('provider_unauthorized'::character varying)::text, ('unsafe_destination'::character varying)::text, ('malformed_response'::character varying)::text, ('attempt_limit'::character varying)::text, ('dns_nxdomain'::character varying)::text, ('dns_no_record'::character varying)::text, ('dns_propagating'::character varying)::text, ('dns_timeout'::character varying)::text, ('dns_transient_failure'::character varying)::text, ('dns_multiple_records'::character varying)::text, ('dns_response_limit'::character varying)::text, ('dns_cname_limit'::character varying)::text, ('dns_delegation_limit'::character varying)::text, ('http_dns_failure'::character varying)::text, ('http_timeout'::character varying)::text, ('http_transport_failure'::character varying)::text, ('http_redirect_rejected'::character varying)::text, ('http_redirect_limit'::character varying)::text, ('http_response_too_large'::character varying)::text, ('http_content_type_rejected'::character varying)::text, ('duplicate_meta'::character varying)::text, ('provider_scope_revoked'::character varying)::text, ('provider_property_inaccessible'::character varying)::text, ('provider_outage'::character varying)::text, ('provider_ambiguous_match'::character varying)::text, ('provider_no_match'::character varying)::text, ('provider_insufficient_permission'::character varying)::text, ('provider_connection_changed'::character varying)::text])))),
    CONSTRAINT domain_verifications_lifecycle CHECK (((((state)::text = 'pending'::text) AND (verified_at IS NULL) AND (failed_at IS NULL) AND (expired_at IS NULL) AND (revoked_at IS NULL) AND (failure_category IS NULL)) OR (((state)::text = 'verified'::text) AND (verified_at IS NOT NULL) AND (failed_at IS NULL) AND (expired_at IS NULL) AND (revoked_at IS NULL) AND (failure_category IS NULL)) OR (((state)::text = 'failed'::text) AND (verified_at IS NULL) AND (failed_at IS NOT NULL) AND (expired_at IS NULL) AND (revoked_at IS NULL) AND (failure_category IS NOT NULL)) OR (((state)::text = 'expired'::text) AND (failed_at IS NULL) AND (expired_at IS NOT NULL) AND (revoked_at IS NULL) AND (failure_category IS NULL)) OR (((state)::text = 'revoked'::text) AND (failed_at IS NULL) AND (expired_at IS NULL) AND (revoked_at IS NOT NULL) AND (failure_category IS NULL)))),
    CONSTRAINT domain_verifications_method_allowlist CHECK (((method)::text = ANY (ARRAY[('dns_txt'::character varying)::text, ('html_file'::character varying)::text, ('meta_tag'::character varying)::text, ('search_console'::character varying)::text]))),
    CONSTRAINT domain_verifications_search_console_binding CHECK (((((method)::text = 'search_console'::text) AND (integration_connection_id IS NOT NULL) AND (provider_property_identifier IS NOT NULL) AND ((char_length(provider_property_identifier) >= 1) AND (char_length(provider_property_identifier) <= 2048)) AND ((provider_property_type)::text = ANY (ARRAY[('url_prefix'::character varying)::text, ('domain'::character varying)::text])) AND ((provider_permission_level)::text = ANY (ARRAY[('siteOwner'::character varying)::text, ('siteFullUser'::character varying)::text, ('siteRestrictedUser'::character varying)::text, ('siteUnverifiedUser'::character varying)::text])) AND (provider_checked_at IS NOT NULL) AND (connection_revision > 0)) OR (((method)::text <> 'search_console'::text) AND (integration_connection_id IS NULL) AND (provider_property_identifier IS NULL) AND (provider_property_type IS NULL) AND (provider_permission_level IS NULL) AND (provider_checked_at IS NULL) AND (connection_revision IS NULL)))),
    CONSTRAINT domain_verifications_state_allowlist CHECK (((state)::text = ANY (ARRAY[('pending'::character varying)::text, ('verified'::character varying)::text, ('failed'::character varying)::text, ('expired'::character varying)::text, ('revoked'::character varying)::text])))
);


--
-- Name: entitlement_definitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entitlement_definitions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key character varying(96) NOT NULL,
    value_type character varying(16) NOT NULL,
    unit character varying(32) NOT NULL,
    category character varying(32) NOT NULL,
    minimum_value numeric(24,6),
    maximum_value numeric(24,6),
    allowed_values jsonb DEFAULT '[]'::jsonb NOT NULL,
    max_length integer,
    allow_custom boolean DEFAULT false NOT NULL,
    security_sensitive boolean DEFAULT false NOT NULL,
    system_default jsonb NOT NULL,
    customer_description character varying(240) NOT NULL,
    catalog_checksum character varying(64) NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT entitlement_definitions_allowed_values_shape CHECK (((jsonb_typeof(allowed_values) = 'array'::text) AND (pg_column_size(allowed_values) <= 4096))),
    CONSTRAINT entitlement_definitions_bounds_order CHECK (((minimum_value IS NULL) OR (maximum_value IS NULL) OR (minimum_value <= maximum_value))),
    CONSTRAINT entitlement_definitions_checksum_format CHECK (((catalog_checksum)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT entitlement_definitions_default_type CHECK (((((value_type)::text = 'boolean'::text) AND (jsonb_typeof(system_default) = 'boolean'::text)) OR (((value_type)::text = 'integer'::text) AND (jsonb_typeof(system_default) = 'number'::text) AND ((system_default #>> '{}'::text[]) ~ '^-?(0|[1-9][0-9]*)$'::text)) OR (((value_type)::text = 'decimal'::text) AND (jsonb_typeof(system_default) = 'string'::text) AND ((system_default #>> '{}'::text[]) ~ '^-?(0|[1-9][0-9]*)(\.[0-9]+)?$'::text)) OR (((value_type)::text = ANY (ARRAY[('enum'::character varying)::text, ('string'::character varying)::text])) AND (jsonb_typeof(system_default) = 'string'::text)))),
    CONSTRAINT entitlement_definitions_description_format CHECK (((char_length((customer_description)::text) >= 3) AND (char_length((customer_description)::text) <= 240) AND ((customer_description)::text = btrim((customer_description)::text)))),
    CONSTRAINT entitlement_definitions_key_format CHECK (((key)::text ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'::text)),
    CONSTRAINT entitlement_definitions_max_length_range CHECK (((max_length IS NULL) OR ((max_length >= 1) AND (max_length <= 4096)))),
    CONSTRAINT entitlement_definitions_security_default CHECK (((security_sensitive = false) OR (((value_type)::text = 'boolean'::text) AND (system_default = 'false'::jsonb)) OR (((value_type)::text = 'integer'::text) AND (system_default = '0'::jsonb)) OR (((value_type)::text = 'decimal'::text) AND ((system_default #>> '{}'::text[]) = '0'::text)) OR (((value_type)::text = ANY (ARRAY[('enum'::character varying)::text, ('string'::character varying)::text])) AND ((system_default #>> '{}'::text[]) = ANY (ARRAY['none'::text, 'disabled'::text]))))),
    CONSTRAINT entitlement_definitions_taxonomy_format CHECK ((((unit)::text ~ '^[a-z][a-z0-9_]{1,31}$'::text) AND ((category)::text ~ '^[a-z][a-z0-9_]{1,31}$'::text))),
    CONSTRAINT entitlement_definitions_type_allowlist CHECK (((value_type)::text = ANY (ARRAY[('boolean'::character varying)::text, ('integer'::character varying)::text, ('decimal'::character varying)::text, ('enum'::character varying)::text, ('string'::character varying)::text]))),
    CONSTRAINT entitlement_definitions_validation_shape CHECK (((((value_type)::text = 'boolean'::text) AND (minimum_value IS NULL) AND (maximum_value IS NULL) AND (allowed_values = '[]'::jsonb) AND (max_length IS NULL) AND (allow_custom = false)) OR (((value_type)::text = ANY (ARRAY[('integer'::character varying)::text, ('decimal'::character varying)::text])) AND (minimum_value IS NOT NULL) AND (maximum_value IS NOT NULL) AND (minimum_value <= maximum_value) AND (allowed_values = '[]'::jsonb) AND (max_length IS NULL)) OR (((value_type)::text = 'enum'::text) AND (minimum_value IS NULL) AND (maximum_value IS NULL) AND (jsonb_array_length(allowed_values) > 0) AND (max_length IS NULL)) OR (((value_type)::text = 'string'::text) AND (minimum_value IS NULL) AND (maximum_value IS NULL) AND (allowed_values = '[]'::jsonb) AND ((max_length >= 1) AND (max_length <= 4096)))))
);


--
-- Name: entitlement_subscription_contexts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entitlement_subscription_contexts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    subscription_id uuid NOT NULL,
    plan_version_id uuid NOT NULL,
    subscription_revision bigint NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    subscription_status character varying(24) NOT NULL,
    access_state character varying(24) NOT NULL,
    grace_ends_at timestamp(6) with time zone,
    access_expires_at timestamp(6) with time zone,
    CONSTRAINT entitlement_contexts_access_state_allowlist CHECK (((access_state)::text = ANY (ARRAY[('pending'::character varying)::text, ('full'::character varying)::text, ('grace'::character varying)::text, ('read_only'::character varying)::text, ('suspended'::character varying)::text]))),
    CONSTRAINT entitlement_contexts_nonnegative_revision CHECK ((subscription_revision >= 0)),
    CONSTRAINT entitlement_contexts_subscription_status_allowlist CHECK (((subscription_status)::text = ANY (ARRAY[('pending'::character varying)::text, ('incomplete'::character varying)::text, ('trialing'::character varying)::text, ('active'::character varying)::text, ('past_due'::character varying)::text, ('paused'::character varying)::text, ('canceled'::character varying)::text, ('expired'::character varying)::text])))
);


--
-- Name: identities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.identities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    email public.citext,
    email_verified boolean DEFAULT false NOT NULL,
    last_authenticated_at timestamp(6) with time zone NOT NULL,
    profile jsonb DEFAULT '{}'::jsonb NOT NULL,
    provider character varying(32) NOT NULL,
    provider_subject character varying(255) NOT NULL,
    revoked_at timestamp(6) with time zone,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id uuid NOT NULL,
    CONSTRAINT identities_normalized_email CHECK (((email IS NULL) OR ((char_length((email)::text) >= 3) AND (char_length((email)::text) <= 320) AND ((email)::text = lower((email)::text))))),
    CONSTRAINT identities_profile_keys CHECK ((((((profile - 'name'::text) - 'login'::text) - 'avatar_url'::text) - 'locale'::text) = '{}'::jsonb)),
    CONSTRAINT identities_profile_object CHECK (((jsonb_typeof(profile) = 'object'::text) AND (octet_length((profile)::text) <= 8192))),
    CONSTRAINT identities_provider_allowlist CHECK (((provider)::text = ANY (ARRAY[('google'::character varying)::text, ('github'::character varying)::text]))),
    CONSTRAINT identities_revocation_follows_creation CHECK (((revoked_at IS NULL) OR (revoked_at >= created_at))),
    CONSTRAINT identities_subject_format CHECK (((char_length((provider_subject)::text) >= 1) AND (char_length((provider_subject)::text) <= 255) AND ((provider_subject)::text = btrim((provider_subject)::text)))),
    CONSTRAINT identities_verified_email_present CHECK (((NOT email_verified) OR (email IS NOT NULL)))
);


--
-- Name: integration_connections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.integration_connections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    connected_by_membership_id uuid NOT NULL,
    provider character varying(32) NOT NULL,
    external_account_id character varying(255) NOT NULL,
    consent_kind character varying(48) NOT NULL,
    consent_digest character varying(64) NOT NULL,
    granted_scopes jsonb DEFAULT '[]'::jsonb NOT NULL,
    state character varying(32) DEFAULT 'connected'::character varying NOT NULL,
    credential_revision integer DEFAULT 1 NOT NULL,
    consented_at timestamp(6) with time zone NOT NULL,
    last_checked_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT integration_connections_consent_digest_format CHECK (((consent_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT integration_connections_lifecycle CHECK (((credential_revision > 0) AND ((((state)::text = 'revoked'::text) AND (revoked_at IS NOT NULL)) OR (((state)::text <> 'revoked'::text) AND (revoked_at IS NULL))))),
    CONSTRAINT integration_connections_provider_allowlist CHECK (((provider)::text = 'search_console'::text)),
    CONSTRAINT integration_connections_scopes_shape CHECK (((jsonb_typeof(granted_scopes) = 'array'::text) AND (octet_length((granted_scopes)::text) <= 2048))),
    CONSTRAINT integration_connections_separate_consent CHECK (((consent_kind)::text = 'search_console_oauth'::text)),
    CONSTRAINT integration_connections_state_allowlist CHECK (((state)::text = ANY (ARRAY[('connected'::character varying)::text, ('healthy'::character varying)::text, ('degraded'::character varying)::text, ('reauthorization_required'::character varying)::text, ('revoked'::character varying)::text])))
);


--
-- Name: invitation_rate_limit_buckets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invitation_rate_limit_buckets (
    created_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    key_digest character varying(64) NOT NULL,
    request_count integer NOT NULL,
    scope character varying(32) NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    window_started_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT invitation_rate_limits_bounded_window CHECK ((expires_at > window_started_at)),
    CONSTRAINT invitation_rate_limits_key_digest_format CHECK (((key_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT invitation_rate_limits_positive_count CHECK ((request_count > 0)),
    CONSTRAINT invitation_rate_limits_scope_allowlist CHECK (((scope)::text = ANY (ARRAY[('issue_actor'::character varying)::text, ('issue_destination'::character varying)::text, ('accept_ip'::character varying)::text])))
);


--
-- Name: invitations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invitations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    accepted_at timestamp(6) with time zone,
    accepted_by_membership_id uuid,
    created_at timestamp(6) with time zone NOT NULL,
    email public.citext NOT NULL,
    expired_at timestamp(6) with time zone,
    expires_at timestamp(6) with time zone NOT NULL,
    initial_role_key character varying(64),
    initial_scope_id uuid,
    initial_scope_type character varying(32),
    invited_by_membership_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    revoked_at timestamp(6) with time zone,
    status character varying(24) DEFAULT 'pending'::character varying NOT NULL,
    superseded_at timestamp(6) with time zone,
    token_digest character varying(64) NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT invitations_email_format CHECK (((char_length((email)::text) >= 3) AND (char_length((email)::text) <= 320) AND ((email)::text = lower(btrim((email)::text))))),
    CONSTRAINT invitations_expiry_window CHECK (((expires_at > created_at) AND (expires_at <= (created_at + '30 days'::interval)))),
    CONSTRAINT invitations_initial_access_consistency CHECK ((((initial_role_key IS NULL) AND (initial_scope_type IS NULL) AND (initial_scope_id IS NULL)) OR (((initial_role_key)::text = ANY (ARRAY[('organization_admin'::character varying)::text, ('billing_admin'::character varying)::text, ('seo_lead'::character varying)::text, ('developer'::character varying)::text, ('content_editor'::character varying)::text, ('analyst'::character varying)::text, ('viewer'::character varying)::text])) AND ((initial_scope_type)::text = 'Organization'::text) AND (initial_scope_id = organization_id)))),
    CONSTRAINT invitations_lifecycle_consistency CHECK (((((status)::text = 'pending'::text) AND (accepted_at IS NULL) AND (accepted_by_membership_id IS NULL) AND (revoked_at IS NULL) AND (expired_at IS NULL) AND (superseded_at IS NULL)) OR (((status)::text = 'accepted'::text) AND (accepted_at IS NOT NULL) AND (accepted_by_membership_id IS NOT NULL) AND (revoked_at IS NULL) AND (expired_at IS NULL) AND (superseded_at IS NULL)) OR (((status)::text = 'revoked'::text) AND (revoked_at IS NOT NULL) AND (accepted_at IS NULL) AND (accepted_by_membership_id IS NULL) AND (expired_at IS NULL) AND (superseded_at IS NULL)) OR (((status)::text = 'expired'::text) AND (expired_at IS NOT NULL) AND (accepted_at IS NULL) AND (accepted_by_membership_id IS NULL) AND (revoked_at IS NULL) AND (superseded_at IS NULL)) OR (((status)::text = 'superseded'::text) AND (superseded_at IS NOT NULL) AND (accepted_at IS NULL) AND (accepted_by_membership_id IS NULL) AND (revoked_at IS NULL) AND (expired_at IS NULL)))),
    CONSTRAINT invitations_status_allowlist CHECK (((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('accepted'::character varying)::text, ('revoked'::character varying)::text, ('expired'::character varying)::text, ('superseded'::character varying)::text]))),
    CONSTRAINT invitations_token_digest_format CHECK (((token_digest)::text ~ '^[0-9a-f]{64}$'::text))
);


--
-- Name: ios_property_configs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ios_property_configs (
    property_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_kind character varying(32) DEFAULT 'ios_app'::character varying NOT NULL,
    configuration_version integer DEFAULT 1 NOT NULL,
    bundle_id public.citext NOT NULL,
    team_id character varying(10) NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT ios_configs_bundle_format CHECK ((((bundle_id)::text = lower((bundle_id)::text)) AND ((bundle_id)::text ~ '^[a-z][a-z0-9-]*(\.[a-z][a-z0-9-]*)+$'::text))),
    CONSTRAINT ios_configs_team_format CHECK (((team_id)::text ~ '^[A-Z0-9]{10}$'::text)),
    CONSTRAINT ios_configs_type_and_version CHECK ((((property_kind)::text = 'ios_app'::text) AND (configuration_version = 1)))
);


--
-- Name: memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.memberships (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    accepted_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    display_name character varying(160) NOT NULL,
    last_accessed_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    organization_id uuid NOT NULL,
    removed_at timestamp(6) with time zone,
    status character varying(32) DEFAULT 'active'::character varying NOT NULL,
    suspended_at timestamp(6) with time zone,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id uuid NOT NULL,
    CONSTRAINT memberships_display_name_format CHECK (((char_length((display_name)::text) >= 1) AND (char_length((display_name)::text) <= 160) AND ((display_name)::text = btrim((display_name)::text)))),
    CONSTRAINT memberships_lifecycle_consistency CHECK (((((status)::text = 'invited'::text) AND (accepted_at IS NULL) AND (suspended_at IS NULL) AND (removed_at IS NULL)) OR (((status)::text = 'active'::text) AND (accepted_at IS NOT NULL) AND (suspended_at IS NULL) AND (removed_at IS NULL)) OR (((status)::text = 'suspended'::text) AND (accepted_at IS NOT NULL) AND (suspended_at IS NOT NULL) AND (removed_at IS NULL)) OR (((status)::text = 'removed'::text) AND (suspended_at IS NULL) AND (removed_at IS NOT NULL)))),
    CONSTRAINT memberships_status_allowlist CHECK (((status)::text = ANY (ARRAY[('invited'::character varying)::text, ('active'::character varying)::text, ('suspended'::character varying)::text, ('removed'::character varying)::text])))
);


--
-- Name: oauth_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oauth_transactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    attempt_count integer DEFAULT 0 NOT NULL,
    consumed_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    initiator_digest character varying(64) NOT NULL,
    last_attempted_at timestamp(6) with time zone,
    link_intent boolean DEFAULT false NOT NULL,
    link_session_id uuid,
    nonce_digest character varying(64),
    pkce_verifier_ciphertext text NOT NULL,
    pkce_verifier_digest character varying(64) NOT NULL,
    provider character varying(32) NOT NULL,
    return_to text DEFAULT '/dashboard'::text NOT NULL,
    state_digest character varying(64) NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT oauth_transactions_attempt_count_nonnegative CHECK ((attempt_count >= 0)),
    CONSTRAINT oauth_transactions_attempt_metadata CHECK ((((attempt_count = 0) AND (last_attempted_at IS NULL)) OR ((attempt_count > 0) AND (last_attempted_at IS NOT NULL)))),
    CONSTRAINT oauth_transactions_bounded_expiry CHECK (((expires_at > created_at) AND (expires_at <= (created_at + '00:15:00'::interval)))),
    CONSTRAINT oauth_transactions_consumption_metadata CHECK (((consumed_at IS NULL) OR ((last_attempted_at IS NOT NULL) AND (consumed_at <= last_attempted_at)))),
    CONSTRAINT oauth_transactions_google_nonce_required CHECK ((((provider)::text <> 'google'::text) OR (nonce_digest IS NOT NULL))),
    CONSTRAINT oauth_transactions_initiator_digest_format CHECK (((initiator_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT oauth_transactions_link_binding CHECK ((((NOT link_intent) AND (link_session_id IS NULL)) OR (link_intent AND (link_session_id IS NOT NULL)))),
    CONSTRAINT oauth_transactions_nonce_digest_format CHECK (((nonce_digest IS NULL) OR ((nonce_digest)::text ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT oauth_transactions_pkce_ciphertext_length CHECK (((char_length(pkce_verifier_ciphertext) >= 32) AND (char_length(pkce_verifier_ciphertext) <= 4096))),
    CONSTRAINT oauth_transactions_pkce_digest_format CHECK (((pkce_verifier_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT oauth_transactions_provider_allowlist CHECK (((provider)::text = ANY (ARRAY[('google'::character varying)::text, ('github'::character varying)::text]))),
    CONSTRAINT oauth_transactions_safe_return_path CHECK (((return_to ~ '^/dashboard(?:/[A-Za-z0-9_-]+)*$'::text) AND (char_length(return_to) <= 2048))),
    CONSTRAINT oauth_transactions_state_digest_format CHECK (((state_digest)::text ~ '^[0-9a-f]{64}$'::text))
);


--
-- Name: organization_entitlement_overrides; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organization_entitlement_overrides (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    entitlement_definition_id uuid NOT NULL,
    value_type character varying(16) NOT NULL,
    value jsonb NOT NULL,
    starts_at timestamp(6) with time zone NOT NULL,
    ends_at timestamp(6) with time zone,
    reason character varying(500) NOT NULL,
    source character varying(24) NOT NULL,
    created_by_membership_id uuid NOT NULL,
    revoked_at timestamp(6) with time zone,
    revoked_by_membership_id uuid,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT entitlement_overrides_reason_format CHECK (((char_length((reason)::text) >= 3) AND (char_length((reason)::text) <= 500) AND ((reason)::text = btrim((reason)::text)))),
    CONSTRAINT entitlement_overrides_revocation_shape CHECK ((((revoked_at IS NULL) AND (revoked_by_membership_id IS NULL)) OR ((revoked_at IS NOT NULL) AND (revoked_by_membership_id IS NOT NULL) AND (revoked_at >= created_at)))),
    CONSTRAINT entitlement_overrides_source_allowlist CHECK (((source)::text = ANY (ARRAY[('contract'::character varying)::text, ('support'::character varying)::text, ('emergency'::character varying)::text]))),
    CONSTRAINT entitlement_overrides_typed_value_shape CHECK (((((value_type)::text = 'boolean'::text) AND (jsonb_typeof(value) = 'boolean'::text)) OR (((value_type)::text = 'integer'::text) AND (jsonb_typeof(value) = 'number'::text) AND ((value #>> '{}'::text[]) ~ '^-?(0|[1-9][0-9]*)$'::text)) OR (((value_type)::text = 'decimal'::text) AND (jsonb_typeof(value) = 'string'::text) AND ((value #>> '{}'::text[]) ~ '^-?(0|[1-9][0-9]*)(\.[0-9]+)?$'::text)) OR (((value_type)::text = ANY (ARRAY[('enum'::character varying)::text, ('string'::character varying)::text])) AND (jsonb_typeof(value) = 'string'::text)))),
    CONSTRAINT entitlement_overrides_validity_order CHECK (((ends_at IS NULL) OR (ends_at > starts_at)))
);


--
-- Name: organization_ownerships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organization_ownerships (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    assigned_at timestamp(6) with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    current boolean DEFAULT true NOT NULL,
    ended_at timestamp(6) with time zone,
    membership_id uuid NOT NULL,
    membership_status character varying(32) DEFAULT 'active'::character varying,
    organization_id uuid NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT organization_ownerships_current_state CHECK ((((current = true) AND (ended_at IS NULL) AND ((membership_status)::text = 'active'::text)) OR ((current = false) AND (ended_at IS NOT NULL) AND (membership_status IS NULL)))),
    CONSTRAINT organization_ownerships_timestamp_order CHECK (((ended_at IS NULL) OR (ended_at >= assigned_at)))
);


--
-- Name: organization_slug_aliases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organization_slug_aliases (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    organization_id uuid NOT NULL,
    slug public.citext NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT organization_slug_aliases_format CHECK (((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]{1,61}[a-z0-9])$'::text)),
    CONSTRAINT organization_slug_aliases_not_reserved CHECK (((slug)::text <> ALL (ARRAY['account'::text, 'billing'::text, 'invitations'::text, 'members'::text, 'new'::text, 'projects'::text, 'roles'::text, 'security'::text, 'settings'::text, 'switch'::text, 'teams'::text])))
);


--
-- Name: organizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organizations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    current_ownership_active boolean DEFAULT true NOT NULL,
    current_ownership_id uuid NOT NULL,
    data_region character varying(32) DEFAULT 'global'::character varying NOT NULL,
    default_locale character varying(16) DEFAULT 'en'::character varying NOT NULL,
    deleted_at timestamp(6) with time zone,
    deletion_requested_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    name character varying(160) NOT NULL,
    slug public.citext NOT NULL,
    status character varying(32) DEFAULT 'active'::character varying NOT NULL,
    suspended_at timestamp(6) with time zone,
    time_zone character varying(64) DEFAULT 'UTC'::character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT organizations_current_ownership_active CHECK ((current_ownership_active = true)),
    CONSTRAINT organizations_data_region_format CHECK (((data_region)::text ~ '^[a-z][a-z0-9_-]{1,31}$'::text)),
    CONSTRAINT organizations_lifecycle_consistency CHECK (((((status)::text = 'active'::text) AND (suspended_at IS NULL) AND (deletion_requested_at IS NULL) AND (deleted_at IS NULL)) OR (((status)::text = 'suspended'::text) AND (suspended_at IS NOT NULL) AND (deletion_requested_at IS NULL) AND (deleted_at IS NULL)) OR (((status)::text = 'pending_deletion'::text) AND (deletion_requested_at IS NOT NULL) AND (deleted_at IS NULL)) OR (((status)::text = 'deleted'::text) AND (deletion_requested_at IS NOT NULL) AND (deleted_at IS NOT NULL) AND (deleted_at >= deletion_requested_at)))),
    CONSTRAINT organizations_locale_format CHECK (((default_locale)::text ~ '^[a-z]{2}(?:-[A-Z]{2})?$'::text)),
    CONSTRAINT organizations_name_format CHECK (((char_length((name)::text) >= 2) AND (char_length((name)::text) <= 160) AND ((name)::text = btrim((name)::text)))),
    CONSTRAINT organizations_slug_format CHECK (((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]{1,61}[a-z0-9])$'::text)),
    CONSTRAINT organizations_slug_not_reserved CHECK (((slug)::text <> ALL (ARRAY['account'::text, 'billing'::text, 'invitations'::text, 'members'::text, 'new'::text, 'projects'::text, 'roles'::text, 'security'::text, 'settings'::text, 'switch'::text, 'teams'::text]))),
    CONSTRAINT organizations_status_allowlist CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('suspended'::character varying)::text, ('pending_deletion'::character varying)::text, ('deleted'::character varying)::text])))
);


--
-- Name: outbox_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.outbox_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    aggregate_type character varying(48) NOT NULL,
    aggregate_id uuid NOT NULL,
    event_type character varying(96) NOT NULL,
    event_version integer DEFAULT 1 NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    idempotency_key character varying(64) NOT NULL,
    occurred_at timestamp(6) with time zone NOT NULL,
    published_at timestamp(6) with time zone,
    attempt_count integer DEFAULT 0 NOT NULL,
    last_attempted_at timestamp(6) with time zone,
    last_error_category character varying(64),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT outbox_events_aggregate_type_format CHECK (((aggregate_type)::text ~ '^[A-Z][A-Za-z0-9]{0,47}$'::text)),
    CONSTRAINT outbox_events_event_type_format CHECK (((event_type)::text ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'::text)),
    CONSTRAINT outbox_events_idempotency_format CHECK (((idempotency_key)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT outbox_events_payload_bounded CHECK (((jsonb_typeof(payload) = 'object'::text) AND (pg_column_size(payload) <= 8192))),
    CONSTRAINT outbox_events_positive_counters CHECK (((event_version > 0) AND (attempt_count >= 0))),
    CONSTRAINT outbox_events_publish_shape CHECK (((published_at IS NULL) OR ((last_attempted_at IS NOT NULL) AND (last_error_category IS NULL))))
);


--
-- Name: permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permissions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    active boolean DEFAULT true NOT NULL,
    catalog_checksum character varying(64) NOT NULL,
    category character varying(64) NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    description text NOT NULL,
    key character varying(128) NOT NULL,
    risk_level character varying(16) NOT NULL,
    scope character varying(32) NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT permissions_catalog_checksum_format CHECK (((catalog_checksum)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT permissions_category_format CHECK (((char_length((category)::text) >= 2) AND (char_length((category)::text) <= 64) AND ((category)::text = btrim((category)::text)))),
    CONSTRAINT permissions_description_format CHECK (((char_length(description) >= 1) AND (char_length(description) <= 500) AND (description = btrim(description)))),
    CONSTRAINT permissions_key_format CHECK (((key)::text ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'::text)),
    CONSTRAINT permissions_risk_allowlist CHECK (((risk_level)::text = ANY (ARRAY[('low'::character varying)::text, ('medium'::character varying)::text, ('high'::character varying)::text, ('critical'::character varying)::text]))),
    CONSTRAINT permissions_scope_allowlist CHECK (((scope)::text = ANY (ARRAY[('organization'::character varying)::text, ('project'::character varying)::text])))
);


--
-- Name: plan_catalog_access_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plan_catalog_access_grants (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    permission character varying(32) NOT NULL,
    granted_at timestamp(6) with time zone NOT NULL,
    revoked_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT plan_catalog_grants_permission_allowlist CHECK (((permission)::text = ANY (ARRAY[('plan_catalog.read'::character varying)::text, ('plan_catalog.publish'::character varying)::text]))),
    CONSTRAINT plan_catalog_grants_revocation_order CHECK (((revoked_at IS NULL) OR (revoked_at >= granted_at)))
);


--
-- Name: plan_entitlements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plan_entitlements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    plan_version_id uuid NOT NULL,
    entitlement_definition_id uuid NOT NULL,
    value_type character varying(16) NOT NULL,
    value_state character varying(16) NOT NULL,
    value jsonb,
    catalog_checksum character varying(64) NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT plan_entitlements_checksum_format CHECK (((catalog_checksum)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT plan_entitlements_typed_value_shape CHECK (((((value_state)::text = 'custom'::text) AND (value IS NULL)) OR (((value_state)::text = 'configured'::text) AND ((((value_type)::text = 'boolean'::text) AND (jsonb_typeof(value) = 'boolean'::text)) OR (((value_type)::text = 'integer'::text) AND (jsonb_typeof(value) = 'number'::text) AND ((value #>> '{}'::text[]) ~ '^-?(0|[1-9][0-9]*)$'::text)) OR (((value_type)::text = 'decimal'::text) AND (jsonb_typeof(value) = 'string'::text) AND ((value #>> '{}'::text[]) ~ '^-?(0|[1-9][0-9]*)(\.[0-9]+)?$'::text)) OR (((value_type)::text = ANY (ARRAY[('enum'::character varying)::text, ('string'::character varying)::text])) AND (jsonb_typeof(value) = 'string'::text))))))
);


--
-- Name: plan_version_snapshot_references; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plan_version_snapshot_references (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    plan_version_id uuid NOT NULL,
    reference_type character varying(32) NOT NULL,
    reference_id uuid NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT plan_version_snapshot_references_type_allowlist CHECK (((reference_type)::text = ANY (ARRAY[('InvoiceSnapshot'::character varying)::text, ('ReportSnapshot'::character varying)::text])))
);


--
-- Name: plan_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plan_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    plan_id uuid NOT NULL,
    version integer NOT NULL,
    status character varying(24) DEFAULT 'draft'::character varying NOT NULL,
    display_name character varying(80) NOT NULL,
    positioning character varying(240) NOT NULL,
    currency character varying(3) DEFAULT 'EUR'::character varying NOT NULL,
    pricing_kind character varying(16) NOT NULL,
    monthly_price_cents bigint,
    annual_price_cents bigint,
    entitlements_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    catalog_checksum character varying(64) NOT NULL,
    effective_at timestamp(6) with time zone,
    published_at timestamp(6) with time zone,
    retired_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT plan_versions_checksum_format CHECK (((catalog_checksum)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT plan_versions_entitlements_snapshot_bounded CHECK (((jsonb_typeof(entitlements_snapshot) = 'object'::text) AND (pg_column_size(entitlements_snapshot) <= 32768))),
    CONSTRAINT plan_versions_lifecycle_shape CHECK (((((status)::text = 'draft'::text) AND (effective_at IS NULL) AND (published_at IS NULL) AND (retired_at IS NULL)) OR (((status)::text = 'published'::text) AND (effective_at IS NOT NULL) AND (published_at IS NOT NULL) AND (retired_at IS NULL)) OR (((status)::text = ANY (ARRAY[('retired'::character varying)::text, ('grandfathered'::character varying)::text])) AND (effective_at IS NOT NULL) AND (published_at IS NOT NULL) AND (retired_at IS NOT NULL)))),
    CONSTRAINT plan_versions_positive_version CHECK ((version > 0)),
    CONSTRAINT plan_versions_pricing_shape CHECK (((((pricing_kind)::text = 'fixed'::text) AND (monthly_price_cents IS NOT NULL) AND (monthly_price_cents >= 0) AND (annual_price_cents IS NOT NULL) AND (annual_price_cents >= 0)) OR (((pricing_kind)::text = 'custom'::text) AND (monthly_price_cents IS NULL) AND (annual_price_cents IS NULL)))),
    CONSTRAINT plan_versions_status_allowlist CHECK (((status)::text = ANY (ARRAY[('draft'::character varying)::text, ('published'::character varying)::text, ('retired'::character varying)::text, ('grandfathered'::character varying)::text])))
);


--
-- Name: plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plans (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key character varying(32) NOT NULL,
    display_order integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT plans_display_order_range CHECK (((display_order >= 1) AND (display_order <= 5))),
    CONSTRAINT plans_key_allowlist CHECK (((key)::text = ANY (ARRAY[('free'::character varying)::text, ('starter'::character varying)::text, ('growth'::character varying)::text, ('agency'::character varying)::text, ('enterprise'::character varying)::text])))
);


--
-- Name: project_onboarding_drafts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_onboarding_drafts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    actor_membership_id uuid NOT NULL,
    project_id uuid NOT NULL,
    website_property_id uuid NOT NULL,
    android_property_id uuid NOT NULL,
    ios_property_id uuid NOT NULL,
    project_release_key character varying(36) NOT NULL,
    state character varying(24) DEFAULT 'draft'::character varying NOT NULL,
    current_step character varying(24) DEFAULT 'project'::character varying NOT NULL,
    last_completed_step character varying(24),
    flow_type character varying(24),
    project_name character varying(160),
    project_slug public.citext,
    project_description text,
    default_locale character varying(16),
    time_zone character varying(64),
    website_kind character varying(32),
    website_display_name character varying(160),
    website_origin text,
    add_android boolean DEFAULT false NOT NULL,
    android_display_name character varying(160),
    android_package_name public.citext,
    add_ios boolean DEFAULT false NOT NULL,
    ios_display_name character varying(160),
    ios_bundle_id public.citext,
    ios_team_id character varying(10),
    verification_method character varying(32),
    crawl_max_urls integer DEFAULT 500 NOT NULL,
    crawl_max_depth integer DEFAULT 5 NOT NULL,
    crawl_query_handling character varying(24) DEFAULT 'tracking_only'::character varying NOT NULL,
    crawl_obey_robots boolean DEFAULT true NOT NULL,
    crawl_rendering boolean DEFAULT false NOT NULL,
    completed_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT project_onboarding_drafts_completion_shape CHECK ((((state)::text = 'draft'::text) OR ((project_name IS NOT NULL) AND (project_slug IS NOT NULL) AND (default_locale IS NOT NULL) AND (time_zone IS NOT NULL) AND (flow_type IS NOT NULL) AND (website_kind IS NOT NULL) AND (website_display_name IS NOT NULL) AND (website_origin IS NOT NULL) AND (verification_method IS NOT NULL) AND ((current_step)::text = 'review'::text) AND ((((flow_type)::text = 'website_only'::text) AND (add_android = false) AND (add_ios = false) AND (android_display_name IS NULL) AND (android_package_name IS NULL) AND (ios_display_name IS NULL) AND (ios_bundle_id IS NULL) AND (ios_team_id IS NULL)) OR (((flow_type)::text = 'combined'::text) AND ((add_android = true) OR (add_ios = true)) AND (((add_android = true) AND (android_display_name IS NOT NULL) AND (android_package_name IS NOT NULL)) OR ((add_android = false) AND (android_display_name IS NULL) AND (android_package_name IS NULL))) AND (((add_ios = true) AND (ios_display_name IS NOT NULL) AND (ios_bundle_id IS NOT NULL) AND (ios_team_id IS NOT NULL)) OR ((add_ios = false) AND (ios_display_name IS NULL) AND (ios_bundle_id IS NULL) AND (ios_team_id IS NULL)))))))),
    CONSTRAINT project_onboarding_drafts_crawl_bounds CHECK (((crawl_max_urls >= 1) AND (crawl_max_urls <= 200000) AND ((crawl_max_depth >= 0) AND (crawl_max_depth <= 20)) AND ((crawl_query_handling)::text = ANY (ARRAY[('ignore'::character varying)::text, ('tracking_only'::character varying)::text, ('all'::character varying)::text])))),
    CONSTRAINT project_onboarding_drafts_flow_type CHECK (((flow_type IS NULL) OR ((flow_type)::text = ANY (ARRAY[('website_only'::character varying)::text, ('combined'::character varying)::text])))),
    CONSTRAINT project_onboarding_drafts_lifecycle CHECK ((((state)::text = ANY (ARRAY[('draft'::character varying)::text, ('completed'::character varying)::text])) AND ((((state)::text = 'draft'::text) AND (completed_at IS NULL)) OR (((state)::text = 'completed'::text) AND (completed_at IS NOT NULL))))),
    CONSTRAINT project_onboarding_drafts_release_key_format CHECK (((project_release_key)::text ~ '^prj_[0-9a-f]{32}$'::text)),
    CONSTRAINT project_onboarding_drafts_steps CHECK ((((current_step)::text = ANY (ARRAY[('project'::character varying)::text, ('product'::character varying)::text, ('property'::character varying)::text, ('verification'::character varying)::text, ('crawl'::character varying)::text, ('review'::character varying)::text])) AND ((last_completed_step IS NULL) OR ((last_completed_step)::text = ANY (ARRAY[('project'::character varying)::text, ('product'::character varying)::text, ('property'::character varying)::text, ('verification'::character varying)::text, ('crawl'::character varying)::text, ('review'::character varying)::text]))))),
    CONSTRAINT project_onboarding_drafts_verification_method CHECK (((verification_method IS NULL) OR ((verification_method)::text = ANY (ARRAY[('dns_txt'::character varying)::text, ('html_file'::character varying)::text, ('meta_tag'::character varying)::text, ('search_console'::character varying)::text])))),
    CONSTRAINT project_onboarding_drafts_website_kind CHECK (((website_kind IS NULL) OR ((website_kind)::text = ANY (ARRAY[('website'::character varying)::text, ('web_application'::character varying)::text]))))
);


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    slug public.citext NOT NULL,
    name character varying(160) NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    status character varying(32) DEFAULT 'active'::character varying NOT NULL,
    default_locale character varying(16) DEFAULT 'en'::character varying NOT NULL,
    time_zone character varying(64) DEFAULT 'UTC'::character varying NOT NULL,
    external_release_key character varying(40) NOT NULL,
    authorization_scope_type character varying(24) DEFAULT 'Project'::character varying NOT NULL,
    archived_at timestamp(6) with time zone,
    deletion_requested_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    work_cancellation_cutoff_at timestamp(6) with time zone,
    deletion_workflow_id uuid,
    CONSTRAINT projects_authorization_scope_type CHECK (((authorization_scope_type)::text = 'Project'::text)),
    CONSTRAINT projects_description_bounded CHECK ((char_length(description) <= 2000)),
    CONSTRAINT projects_external_release_key_format CHECK (((external_release_key)::text ~ '^prj_[0-9a-f]{32}$'::text)),
    CONSTRAINT projects_lifecycle_consistency CHECK (((((status)::text = 'active'::text) AND (archived_at IS NULL) AND (deletion_requested_at IS NULL) AND (deletion_workflow_id IS NULL)) OR (((status)::text = 'archived'::text) AND (archived_at IS NOT NULL) AND (deletion_requested_at IS NULL) AND (deletion_workflow_id IS NULL)) OR (((status)::text = 'pending_deletion'::text) AND (archived_at IS NOT NULL) AND (deletion_requested_at IS NOT NULL) AND (deletion_workflow_id IS NOT NULL) AND (deletion_requested_at >= archived_at)))),
    CONSTRAINT projects_locale_format CHECK (((default_locale)::text ~ '^[a-z]{2}(?:-[A-Z]{2})?$'::text)),
    CONSTRAINT projects_name_format CHECK (((char_length((name)::text) >= 2) AND (char_length((name)::text) <= 160) AND ((name)::text = btrim((name)::text)))),
    CONSTRAINT projects_slug_format CHECK (((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]{1,61}[a-z0-9])$'::text)),
    CONSTRAINT projects_time_zone_format CHECK (((char_length((time_zone)::text) >= 1) AND (char_length((time_zone)::text) <= 64) AND ((time_zone)::text = btrim((time_zone)::text))))
);


--
-- Name: properties; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.properties (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    display_name public.citext NOT NULL,
    kind character varying(32) NOT NULL,
    status character varying(24) DEFAULT 'active'::character varying NOT NULL,
    verification_status character varying(24) DEFAULT 'unverified'::character varying NOT NULL,
    verified_at timestamp(6) with time zone,
    configuration_version integer DEFAULT 1 NOT NULL,
    authorization_scope_type character varying(24) DEFAULT 'Property'::character varying NOT NULL,
    authorization_project_scope_type character varying(24) DEFAULT 'Project'::character varying NOT NULL,
    archived_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    deletion_requested_at timestamp(6) with time zone,
    work_cancellation_cutoff_at timestamp(6) with time zone,
    deletion_workflow_id uuid,
    CONSTRAINT properties_authorization_scope_types CHECK ((((authorization_scope_type)::text = 'Property'::text) AND ((authorization_project_scope_type)::text = 'Project'::text))),
    CONSTRAINT properties_configuration_version CHECK ((configuration_version = 1)),
    CONSTRAINT properties_display_name_format CHECK (((char_length((display_name)::text) >= 2) AND (char_length((display_name)::text) <= 160) AND ((display_name)::text = btrim((display_name)::text)))),
    CONSTRAINT properties_kind_allowlist CHECK (((kind)::text = ANY (ARRAY[('website'::character varying)::text, ('web_application'::character varying)::text, ('android_app'::character varying)::text, ('ios_app'::character varying)::text]))),
    CONSTRAINT properties_lifecycle_consistency CHECK (((((status)::text = 'active'::text) AND (archived_at IS NULL) AND (deletion_requested_at IS NULL) AND (deletion_workflow_id IS NULL)) OR (((status)::text = 'archived'::text) AND (archived_at IS NOT NULL) AND (deletion_requested_at IS NULL) AND (deletion_workflow_id IS NULL)) OR (((status)::text = 'pending_deletion'::text) AND (archived_at IS NOT NULL) AND (deletion_requested_at IS NOT NULL) AND (deletion_workflow_id IS NOT NULL) AND (deletion_requested_at >= archived_at)))),
    CONSTRAINT properties_verification_status_allowlist CHECK (((verification_status)::text = ANY (ARRAY[('unverified'::character varying)::text, ('pending'::character varying)::text, ('verified'::character varying)::text, ('failed'::character varying)::text, ('expired'::character varying)::text, ('revoked'::character varying)::text]))),
    CONSTRAINT properties_verified_timestamp CHECK ((((verification_status)::text <> 'verified'::text) OR (verified_at IS NOT NULL)))
);


--
-- Name: property_environments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.property_environments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid NOT NULL,
    property_kind character varying(32) NOT NULL,
    configuration_version integer DEFAULT 1 NOT NULL,
    key public.citext NOT NULL,
    kind character varying(24) NOT NULL,
    display_name public.citext NOT NULL,
    "primary" boolean DEFAULT false NOT NULL,
    status character varying(24) DEFAULT 'active'::character varying NOT NULL,
    scheme character varying(8) NOT NULL,
    host public.citext NOT NULL,
    port integer NOT NULL,
    origin text NOT NULL,
    archived_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT property_environments_canonical_origin CHECK (((char_length(origin) >= 8) AND (char_length(origin) <= 2048) AND (origin = ((((scheme)::text || '://'::text) || lower((host)::text)) ||
CASE
    WHEN ((((scheme)::text = 'http'::text) AND (port = 80)) OR (((scheme)::text = 'https'::text) AND (port = 443))) THEN ''::text
    ELSE (':'::text || (port)::text)
END)))),
    CONSTRAINT property_environments_display_name_format CHECK (((char_length((display_name)::text) >= 2) AND (char_length((display_name)::text) <= 120) AND ((display_name)::text = btrim((display_name)::text)))),
    CONSTRAINT property_environments_host_format CHECK ((((host)::text = lower((host)::text)) AND ((host)::text ~ '^[a-z0-9](?:[a-z0-9.-]{0,251}[a-z0-9])?$'::text))),
    CONSTRAINT property_environments_key_format CHECK ((((key)::text ~ '^[a-z][a-z0-9-]{1,62}$'::text) AND ((key)::text = lower((key)::text)))),
    CONSTRAINT property_environments_kind_allowlist CHECK (((kind)::text = ANY (ARRAY[('production'::character varying)::text, ('staging'::character varying)::text, ('development'::character varying)::text, ('custom'::character varying)::text]))),
    CONSTRAINT property_environments_lifecycle CHECK (((((status)::text = 'active'::text) AND (archived_at IS NULL)) OR (((status)::text = 'archived'::text) AND (archived_at IS NOT NULL)))),
    CONSTRAINT property_environments_primary_shape CHECK ((("primary" = false) OR (((kind)::text = 'production'::text) AND ((status)::text = 'active'::text)))),
    CONSTRAINT property_environments_property_type CHECK ((((property_kind)::text = ANY (ARRAY[('website'::character varying)::text, ('web_application'::character varying)::text])) AND (configuration_version = 1))),
    CONSTRAINT property_environments_transport CHECK ((((scheme)::text = ANY (ARRAY[('http'::character varying)::text, ('https'::character varying)::text])) AND ((port >= 1) AND (port <= 65535))))
);


--
-- Name: resource_deletion_stage_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.resource_deletion_stage_executions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_deletion_workflow_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    stage character varying(32) NOT NULL,
    "position" integer NOT NULL,
    state character varying(24) DEFAULT 'pending'::character varying NOT NULL,
    attempt_count integer DEFAULT 0 NOT NULL,
    started_at timestamp(6) with time zone,
    completed_at timestamp(6) with time zone,
    last_error_category character varying(64),
    cursor character varying(512),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT deletion_stages_error_category CHECK (((last_error_category IS NULL) OR ((last_error_category)::text ~ '^[a-z][a-z0-9_]{0,63}$'::text))),
    CONSTRAINT deletion_stages_ordered_allowlist CHECK (((((stage)::text = 'cancel_active_work'::text) AND ("position" = 0)) OR (((stage)::text = 'integrations'::text) AND ("position" = 1)) OR (((stage)::text = 'scans_and_findings'::text) AND ("position" = 2)) OR (((stage)::text = 'reports'::text) AND ("position" = 3)) OR (((stage)::text = 'object_artifacts'::text) AND ("position" = 4)) OR (((stage)::text = 'api_keys_and_webhooks'::text) AND ("position" = 5)) OR (((stage)::text = 'aggregate_records'::text) AND ("position" = 6)))),
    CONSTRAINT deletion_stages_state_and_attempts CHECK ((((state)::text = ANY (ARRAY[('pending'::character varying)::text, ('running'::character varying)::text, ('retryable'::character varying)::text, ('completed'::character varying)::text])) AND (attempt_count >= 0)))
);


--
-- Name: resource_deletion_workflows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.resource_deletion_workflows (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    target_type character varying(24) NOT NULL,
    target_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid,
    requested_by_membership_id uuid NOT NULL,
    state character varying(24) DEFAULT 'holding'::character varying NOT NULL,
    current_stage character varying(32),
    requested_at timestamp(6) with time zone NOT NULL,
    hold_until timestamp(6) with time zone NOT NULL,
    started_at timestamp(6) with time zone,
    completed_at timestamp(6) with time zone,
    canceled_at timestamp(6) with time zone,
    next_attempt_at timestamp(6) with time zone,
    last_error_category character varying(64),
    lease_token uuid,
    lease_expires_at timestamp(6) with time zone,
    attempt_count integer DEFAULT 0 NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT deletion_workflows_error_category CHECK (((last_error_category IS NULL) OR ((last_error_category)::text ~ '^[a-z][a-z0-9_]{0,63}$'::text))),
    CONSTRAINT deletion_workflows_stage_allowlist CHECK (((current_stage IS NULL) OR ((current_stage)::text = ANY (ARRAY[('cancel_active_work'::character varying)::text, ('integrations'::character varying)::text, ('scans_and_findings'::character varying)::text, ('reports'::character varying)::text, ('object_artifacts'::character varying)::text, ('api_keys_and_webhooks'::character varying)::text, ('aggregate_records'::character varying)::text])))),
    CONSTRAINT deletion_workflows_state_shape CHECK (((((state)::text = 'holding'::text) AND (current_stage IS NULL) AND (started_at IS NULL) AND (completed_at IS NULL) AND (canceled_at IS NULL) AND (next_attempt_at IS NULL) AND (last_error_category IS NULL) AND (lease_token IS NULL) AND (lease_expires_at IS NULL)) OR (((state)::text = 'running'::text) AND (current_stage IS NOT NULL) AND (started_at IS NOT NULL) AND (completed_at IS NULL) AND (canceled_at IS NULL) AND (next_attempt_at IS NULL) AND (last_error_category IS NULL) AND (lease_token IS NOT NULL) AND (lease_expires_at IS NOT NULL)) OR (((state)::text = 'retryable'::text) AND (current_stage IS NOT NULL) AND (started_at IS NOT NULL) AND (completed_at IS NULL) AND (canceled_at IS NULL) AND (next_attempt_at IS NOT NULL) AND (last_error_category IS NOT NULL) AND (lease_token IS NULL) AND (lease_expires_at IS NULL)) OR (((state)::text = 'completed'::text) AND ((current_stage)::text = 'aggregate_records'::text) AND (started_at IS NOT NULL) AND (completed_at IS NOT NULL) AND (canceled_at IS NULL) AND (next_attempt_at IS NULL) AND (last_error_category IS NULL) AND (lease_token IS NULL) AND (lease_expires_at IS NULL)) OR (((state)::text = 'canceled'::text) AND (current_stage IS NULL) AND (started_at IS NULL) AND (completed_at IS NULL) AND (canceled_at IS NOT NULL) AND (next_attempt_at IS NULL) AND (last_error_category IS NULL) AND (lease_token IS NULL) AND (lease_expires_at IS NULL)))),
    CONSTRAINT deletion_workflows_target_shape CHECK ((((target_type)::text = ANY (ARRAY[('Project'::character varying)::text, ('Property'::character varying)::text])) AND ((((target_type)::text = 'Project'::text) AND (target_id = project_id) AND (property_id IS NULL)) OR (((target_type)::text = 'Property'::text) AND (target_id = property_id) AND (property_id IS NOT NULL))))),
    CONSTRAINT deletion_workflows_time_and_attempts CHECK (((hold_until > requested_at) AND (attempt_count >= 0)))
);


--
-- Name: role_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_assignments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    effect character varying(16) DEFAULT 'allow'::character varying NOT NULL,
    expires_at timestamp(6) with time zone,
    granted_by_membership_id uuid NOT NULL,
    grantee_id uuid NOT NULL,
    grantee_type character varying(24) NOT NULL,
    membership_grantee_id uuid,
    organization_id uuid NOT NULL,
    revoked_at timestamp(6) with time zone,
    revoked_by_membership_id uuid,
    role_id uuid NOT NULL,
    role_organization_id uuid,
    role_system boolean NOT NULL,
    scope_id uuid NOT NULL,
    scope_type character varying(24) NOT NULL,
    team_grantee_id uuid,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT role_assignments_allow_only CHECK (((effect)::text = 'allow'::text)),
    CONSTRAINT role_assignments_expiry_after_creation CHECK (((expires_at IS NULL) OR (expires_at > created_at))),
    CONSTRAINT role_assignments_grantee_shape CHECK (((((grantee_type)::text = 'Membership'::text) AND (membership_grantee_id = grantee_id) AND (team_grantee_id IS NULL)) OR (((grantee_type)::text = 'Team'::text) AND (team_grantee_id = grantee_id) AND (membership_grantee_id IS NULL)))),
    CONSTRAINT role_assignments_revocation_after_creation CHECK (((revoked_at IS NULL) OR (revoked_at >= created_at))),
    CONSTRAINT role_assignments_revocation_consistency CHECK ((((revoked_at IS NULL) AND (revoked_by_membership_id IS NULL)) OR ((revoked_at IS NOT NULL) AND (revoked_by_membership_id IS NOT NULL)))),
    CONSTRAINT role_assignments_role_tenant CHECK ((((role_system = true) AND (role_organization_id IS NULL)) OR ((role_system = false) AND (role_organization_id = organization_id)))),
    CONSTRAINT role_assignments_scope_type_allowlist CHECK (((scope_type)::text = ANY (ARRAY[('Organization'::character varying)::text, ('Project'::character varying)::text, ('Property'::character varying)::text])))
);


--
-- Name: role_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_permissions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    permission_id uuid NOT NULL,
    role_id uuid NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    archived_at timestamp(6) with time zone,
    assignable_scopes character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    catalog_checksum character varying(64),
    created_at timestamp(6) with time zone NOT NULL,
    key character varying(64) NOT NULL,
    mutable boolean DEFAULT true NOT NULL,
    name character varying(80) NOT NULL,
    organization_id uuid,
    system boolean DEFAULT false NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT roles_assignable_scopes_allowlist CHECK (((assignable_scopes = ARRAY['organization'::character varying]) OR (assignable_scopes = ARRAY['project'::character varying]) OR (assignable_scopes = ARRAY['organization'::character varying, 'project'::character varying]))),
    CONSTRAINT roles_key_format CHECK (((key)::text ~ '^[a-z][a-z0-9_]{1,63}$'::text)),
    CONSTRAINT roles_name_format CHECK (((char_length((name)::text) >= 2) AND (char_length((name)::text) <= 80) AND ((name)::text = btrim((name)::text)))),
    CONSTRAINT roles_ownership_consistency CHECK ((((system = true) AND (organization_id IS NULL) AND (mutable = false) AND (archived_at IS NULL) AND ((catalog_checksum)::text ~ '^[0-9a-f]{64}$'::text) AND ((key)::text = ANY (ARRAY[('owner'::character varying)::text, ('organization_admin'::character varying)::text, ('billing_admin'::character varying)::text, ('seo_lead'::character varying)::text, ('developer'::character varying)::text, ('content_editor'::character varying)::text, ('analyst'::character varying)::text, ('viewer'::character varying)::text]))) OR ((system = false) AND (organization_id IS NOT NULL) AND (mutable = true) AND (catalog_checksum IS NULL) AND ((key)::text <> ALL (ARRAY[('owner'::character varying)::text, ('organization_admin'::character varying)::text, ('billing_admin'::character varying)::text, ('seo_lead'::character varying)::text, ('developer'::character varying)::text, ('content_editor'::character varying)::text, ('analyst'::character varying)::text, ('viewer'::character varying)::text])))))
);


--
-- Name: scan_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.scan_events (
    id bigint NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid NOT NULL,
    environment_id uuid NOT NULL,
    scan_id uuid NOT NULL,
    sequence bigint NOT NULL,
    event_type character varying(40) NOT NULL,
    from_status character varying(32),
    to_status character varying(32) NOT NULL,
    actor_membership_id uuid,
    idempotency_key_digest character varying(64) NOT NULL,
    payload_digest character varying(64) NOT NULL,
    targets_count integer NOT NULL,
    urls_discovered_count bigint NOT NULL,
    urls_queued_count bigint NOT NULL,
    urls_running_count bigint NOT NULL,
    urls_processed_count bigint NOT NULL,
    urls_succeeded_count bigint NOT NULL,
    urls_failed_count bigint NOT NULL,
    urls_skipped_count bigint NOT NULL,
    findings_count bigint NOT NULL,
    failure_category character varying(64),
    occurred_at timestamp(6) with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT scan_events_counter_consistency CHECK (((targets_count >= 0) AND (urls_discovered_count >= 0) AND (urls_queued_count >= 0) AND (urls_running_count >= 0) AND (urls_processed_count >= 0) AND (urls_succeeded_count >= 0) AND (urls_failed_count >= 0) AND (urls_skipped_count >= 0) AND (findings_count >= 0) AND (urls_processed_count = ((urls_succeeded_count + urls_failed_count) + urls_skipped_count)) AND (urls_discovered_count >= ((urls_processed_count + urls_queued_count) + urls_running_count)))),
    CONSTRAINT scan_events_digest_shape CHECK ((((idempotency_key_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((payload_digest)::text ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT scan_events_failure_category CHECK (((failure_category IS NULL) OR ((failure_category)::text ~ '^[a-z][a-z0-9_]{0,63}$'::text))),
    CONSTRAINT scan_events_positive_sequence CHECK ((sequence > 0)),
    CONSTRAINT scan_events_status_allowlist CHECK ((((from_status IS NULL) OR ((from_status)::text = ANY (ARRAY[('requested'::character varying)::text, ('admitted'::character varying)::text, ('queued'::character varying)::text, ('running'::character varying)::text, ('cancel_requested'::character varying)::text, ('canceled'::character varying)::text, ('completed'::character varying)::text, ('partially_completed'::character varying)::text, ('failed'::character varying)::text]))) AND ((to_status)::text = ANY (ARRAY[('requested'::character varying)::text, ('admitted'::character varying)::text, ('queued'::character varying)::text, ('running'::character varying)::text, ('cancel_requested'::character varying)::text, ('canceled'::character varying)::text, ('completed'::character varying)::text, ('partially_completed'::character varying)::text, ('failed'::character varying)::text])))),
    CONSTRAINT scan_events_type_allowlist CHECK (((event_type)::text = ANY (ARRAY[('scan.requested'::character varying)::text, ('scan.admitted'::character varying)::text, ('scan.queued'::character varying)::text, ('scan.started'::character varying)::text, ('scan.cancel_requested'::character varying)::text, ('scan.canceled'::character varying)::text, ('scan.completed'::character varying)::text, ('scan.partially_completed'::character varying)::text, ('scan.failed'::character varying)::text, ('scan.progress_recorded'::character varying)::text])))
);


--
-- Name: scan_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.scan_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: scan_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.scan_events_id_seq OWNED BY public.scan_events.id;


--
-- Name: scans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.scans (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_id uuid NOT NULL,
    environment_id uuid NOT NULL,
    scan_type character varying(24) NOT NULL,
    initiator_type character varying(24) NOT NULL,
    initiated_by_membership_id uuid,
    status character varying(32) DEFAULT 'requested'::character varying NOT NULL,
    settings_snapshot jsonb NOT NULL,
    settings_digest character varying(64) NOT NULL,
    entitlement_snapshot jsonb NOT NULL,
    entitlement_digest character varying(64) NOT NULL,
    engine_version character varying(64) NOT NULL,
    rule_set_version character varying(64) NOT NULL,
    configuration_version integer DEFAULT 1 NOT NULL,
    release_id uuid,
    baseline_scan_id uuid,
    targets_count integer DEFAULT 0 NOT NULL,
    urls_discovered_count bigint DEFAULT 0 NOT NULL,
    urls_queued_count bigint DEFAULT 0 NOT NULL,
    urls_running_count bigint DEFAULT 0 NOT NULL,
    urls_processed_count bigint DEFAULT 0 NOT NULL,
    urls_succeeded_count bigint DEFAULT 0 NOT NULL,
    urls_failed_count bigint DEFAULT 0 NOT NULL,
    urls_skipped_count bigint DEFAULT 0 NOT NULL,
    findings_count bigint DEFAULT 0 NOT NULL,
    progress_sequence bigint DEFAULT 1 NOT NULL,
    requested_at timestamp(6) with time zone NOT NULL,
    admitted_at timestamp(6) with time zone,
    queued_at timestamp(6) with time zone,
    started_at timestamp(6) with time zone,
    cancel_requested_at timestamp(6) with time zone,
    canceled_at timestamp(6) with time zone,
    completed_at timestamp(6) with time zone,
    failed_at timestamp(6) with time zone,
    failure_category character varying(64),
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    request_source character varying(24),
    request_idempotency_digest character varying(64),
    request_checksum character varying(64),
    admission_version integer,
    usage_quota_reservation_id uuid,
    domain_verification_id uuid,
    preflight_checked_at timestamp(6) with time zone,
    preflight_status_code integer,
    preflight_destination_digest character varying(64),
    credit_estimate numeric(30,6),
    dispatch_attempted_at timestamp(6) with time zone,
    dispatch_enqueued_at timestamp(6) with time zone,
    dispatch_attempt_count integer DEFAULT 0 NOT NULL,
    dispatch_last_error_category character varying(64),
    throttled_at timestamp(6) with time zone,
    throttle_reason character varying(64),
    throttle_until timestamp(6) with time zone,
    CONSTRAINT scans_admission_provenance_shape CHECK ((((admission_version IS NULL) AND (request_source IS NULL) AND (request_idempotency_digest IS NULL) AND (request_checksum IS NULL) AND (usage_quota_reservation_id IS NULL) AND (domain_verification_id IS NULL) AND (preflight_checked_at IS NULL) AND (preflight_status_code IS NULL) AND (preflight_destination_digest IS NULL) AND (credit_estimate IS NULL)) OR ((admission_version = 1) AND ((request_source)::text = ANY (ARRAY[('manual'::character varying)::text, ('schedule'::character varying)::text, ('release'::character varying)::text])) AND ((request_idempotency_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((request_checksum)::text ~ '^[0-9a-f]{64}$'::text) AND (usage_quota_reservation_id IS NOT NULL) AND (domain_verification_id IS NOT NULL) AND (preflight_checked_at IS NOT NULL) AND ((preflight_status_code >= 100) AND (preflight_status_code <= 499)) AND ((preflight_destination_digest)::text ~ '^[0-9a-f]{64}$'::text) AND (credit_estimate > (0)::numeric)))),
    CONSTRAINT scans_bounded_snapshots CHECK (((jsonb_typeof(settings_snapshot) = 'object'::text) AND (octet_length((settings_snapshot)::text) <= 32768) AND (jsonb_typeof(entitlement_snapshot) = 'object'::text) AND (octet_length((entitlement_snapshot)::text) <= 32768))),
    CONSTRAINT scans_counter_consistency CHECK (((targets_count >= 0) AND (urls_discovered_count >= 0) AND (urls_queued_count >= 0) AND (urls_running_count >= 0) AND (urls_processed_count >= 0) AND (urls_succeeded_count >= 0) AND (urls_failed_count >= 0) AND (urls_skipped_count >= 0) AND (findings_count >= 0) AND (progress_sequence > 0) AND (urls_processed_count = ((urls_succeeded_count + urls_failed_count) + urls_skipped_count)) AND (urls_discovered_count >= ((urls_processed_count + urls_queued_count) + urls_running_count)) AND (((status)::text <> ALL (ARRAY[('canceled'::character varying)::text, ('completed'::character varying)::text, ('partially_completed'::character varying)::text, ('failed'::character varying)::text])) OR ((urls_queued_count = 0) AND (urls_running_count = 0))))),
    CONSTRAINT scans_dispatch_shape CHECK (((dispatch_attempt_count >= 0) AND ((dispatch_attempt_count = 0) OR (dispatch_attempted_at IS NOT NULL)) AND ((dispatch_enqueued_at IS NULL) OR ((dispatch_attempted_at IS NOT NULL) AND (dispatch_enqueued_at >= dispatch_attempted_at) AND (dispatch_last_error_category IS NULL))) AND ((dispatch_last_error_category IS NULL) OR ((dispatch_last_error_category)::text ~ '^[a-z][a-z0-9_]{0,63}$'::text)))),
    CONSTRAINT scans_distinct_baseline CHECK (((baseline_scan_id IS NULL) OR (baseline_scan_id <> id))),
    CONSTRAINT scans_initiator_shape CHECK ((((initiator_type)::text = ANY (ARRAY[('membership'::character varying)::text, ('schedule'::character varying)::text, ('release'::character varying)::text, ('system'::character varying)::text])) AND ((((initiator_type)::text = 'membership'::text) AND (initiated_by_membership_id IS NOT NULL)) OR (((initiator_type)::text <> 'membership'::text) AND (initiated_by_membership_id IS NULL))))),
    CONSTRAINT scans_lifecycle_shape CHECK (((requested_at IS NOT NULL) AND ((admitted_at IS NULL) OR (admitted_at >= requested_at)) AND ((queued_at IS NULL) OR ((admitted_at IS NOT NULL) AND (queued_at >= admitted_at))) AND ((started_at IS NULL) OR ((queued_at IS NOT NULL) AND (started_at >= queued_at))) AND ((cancel_requested_at IS NULL) OR (cancel_requested_at >= requested_at)) AND ((canceled_at IS NULL) OR ((cancel_requested_at IS NOT NULL) AND (canceled_at >= cancel_requested_at))) AND ((completed_at IS NULL) OR ((started_at IS NOT NULL) AND (completed_at >= started_at))) AND ((failed_at IS NULL) OR (failed_at >= requested_at)) AND ((((status)::text = 'requested'::text) AND (admitted_at IS NULL) AND (queued_at IS NULL) AND (started_at IS NULL) AND (cancel_requested_at IS NULL) AND (canceled_at IS NULL) AND (completed_at IS NULL) AND (failed_at IS NULL) AND (failure_category IS NULL)) OR (((status)::text = 'admitted'::text) AND (admitted_at IS NOT NULL) AND (queued_at IS NULL) AND (started_at IS NULL) AND (cancel_requested_at IS NULL) AND (canceled_at IS NULL) AND (completed_at IS NULL) AND (failed_at IS NULL) AND (failure_category IS NULL)) OR (((status)::text = 'queued'::text) AND (admitted_at IS NOT NULL) AND (queued_at IS NOT NULL) AND (started_at IS NULL) AND (cancel_requested_at IS NULL) AND (canceled_at IS NULL) AND (completed_at IS NULL) AND (failed_at IS NULL) AND (failure_category IS NULL)) OR (((status)::text = 'running'::text) AND (admitted_at IS NOT NULL) AND (queued_at IS NOT NULL) AND (started_at IS NOT NULL) AND (cancel_requested_at IS NULL) AND (canceled_at IS NULL) AND (completed_at IS NULL) AND (failed_at IS NULL) AND (failure_category IS NULL)) OR (((status)::text = 'cancel_requested'::text) AND (admitted_at IS NOT NULL) AND (queued_at IS NOT NULL) AND (cancel_requested_at IS NOT NULL) AND (canceled_at IS NULL) AND (completed_at IS NULL) AND (failed_at IS NULL) AND (failure_category IS NULL)) OR (((status)::text = 'canceled'::text) AND (cancel_requested_at IS NOT NULL) AND (canceled_at IS NOT NULL) AND (completed_at IS NULL) AND (failed_at IS NULL) AND (failure_category IS NULL)) OR (((status)::text = ANY (ARRAY[('completed'::character varying)::text, ('partially_completed'::character varying)::text])) AND (started_at IS NOT NULL) AND (completed_at IS NOT NULL) AND (canceled_at IS NULL) AND (failed_at IS NULL) AND (failure_category IS NULL)) OR (((status)::text = 'failed'::text) AND (failed_at IS NOT NULL) AND (completed_at IS NULL) AND (canceled_at IS NULL) AND ((failure_category)::text ~ '^[a-z][a-z0-9_]{0,63}$'::text))))),
    CONSTRAINT scans_snapshot_digests CHECK ((((settings_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((entitlement_digest)::text ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT scans_status_allowlist CHECK (((status)::text = ANY (ARRAY[('requested'::character varying)::text, ('admitted'::character varying)::text, ('queued'::character varying)::text, ('running'::character varying)::text, ('cancel_requested'::character varying)::text, ('canceled'::character varying)::text, ('completed'::character varying)::text, ('partially_completed'::character varying)::text, ('failed'::character varying)::text]))),
    CONSTRAINT scans_type_allowlist CHECK (((scan_type)::text = ANY (ARRAY[('full'::character varying)::text, ('targeted'::character varying)::text, ('verification'::character varying)::text]))),
    CONSTRAINT scans_version_provenance CHECK (((configuration_version > 0) AND ((engine_version)::text ~ '^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$'::text) AND ((rule_set_version)::text ~ '^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$'::text)))
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    authenticated_at timestamp(6) with time zone NOT NULL,
    client_name character varying(32) DEFAULT 'Unknown client'::character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    device_type character varying(16) DEFAULT 'Unknown'::character varying NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    ip_address_digest character varying(64),
    last_seen_at timestamp(6) with time zone NOT NULL,
    revoke_reason character varying(64),
    revoked_at timestamp(6) with time zone,
    rotated_from_id uuid,
    token_digest character varying(64) NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_agent_digest character varying(64),
    user_id uuid NOT NULL,
    CONSTRAINT sessions_authentication_before_last_seen CHECK ((authenticated_at <= last_seen_at)),
    CONSTRAINT sessions_client_name_allowlist CHECK (((client_name)::text = ANY (ARRAY[('Chrome'::character varying)::text, ('Edge'::character varying)::text, ('Firefox'::character varying)::text, ('Safari'::character varying)::text, ('Other client'::character varying)::text, ('Unknown client'::character varying)::text]))),
    CONSTRAINT sessions_device_type_allowlist CHECK (((device_type)::text = ANY (ARRAY[('Desktop'::character varying)::text, ('Mobile'::character varying)::text, ('Tablet'::character varying)::text, ('Unknown'::character varying)::text]))),
    CONSTRAINT sessions_expiry_after_last_seen CHECK ((expires_at > last_seen_at)),
    CONSTRAINT sessions_ip_digest_format CHECK (((ip_address_digest IS NULL) OR ((ip_address_digest)::text ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT sessions_revocation_consistency CHECK ((((revoked_at IS NULL) AND (revoke_reason IS NULL)) OR ((revoked_at IS NOT NULL) AND (revoke_reason IS NOT NULL)))),
    CONSTRAINT sessions_revoke_reason_allowlist CHECK (((revoke_reason IS NULL) OR ((revoke_reason)::text = ANY (ARRAY[('logout'::character varying)::text, ('rotated'::character varying)::text, ('privilege_changed'::character varying)::text, ('user_inactive'::character varying)::text, ('administrative'::character varying)::text])))),
    CONSTRAINT sessions_token_digest_format CHECK (((token_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT sessions_user_agent_digest_format CHECK (((user_agent_digest IS NULL) OR ((user_agent_digest)::text ~ '^[0-9a-f]{64}$'::text)))
);


--
-- Name: subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subscriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    plan_version_id uuid NOT NULL,
    status character varying(24) DEFAULT 'active'::character varying NOT NULL,
    billing_interval character varying(16) NOT NULL,
    plan_key_snapshot character varying(32) NOT NULL,
    plan_version_snapshot integer NOT NULL,
    plan_display_name_snapshot character varying(80) NOT NULL,
    currency_snapshot character varying(3) NOT NULL,
    pricing_kind_snapshot character varying(16) NOT NULL,
    price_cents_snapshot bigint,
    started_at timestamp(6) with time zone NOT NULL,
    ended_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    billing_customer_id uuid,
    provider character varying(32),
    provider_environment character varying(16),
    provider_subscription_id character varying(191),
    access_state character varying(24) DEFAULT 'full'::character varying NOT NULL,
    provider_metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    current_period_starts_at timestamp(6) with time zone,
    current_period_ends_at timestamp(6) with time zone,
    trial_ends_at timestamp(6) with time zone,
    cancel_at_period_end boolean DEFAULT false NOT NULL,
    canceled_at timestamp(6) with time zone,
    provider_updated_at timestamp(6) with time zone,
    last_synced_at timestamp(6) with time zone,
    provider_event_precedence integer DEFAULT 0 NOT NULL,
    provider_event_digest character varying(64),
    grace_ends_at timestamp(6) with time zone,
    access_expires_at timestamp(6) with time zone,
    CONSTRAINT subscriptions_access_state_allowlist CHECK (((access_state)::text = ANY (ARRAY[('pending'::character varying)::text, ('full'::character varying)::text, ('grace'::character varying)::text, ('read_only'::character varying)::text, ('suspended'::character varying)::text]))),
    CONSTRAINT subscriptions_access_timing_shape CHECK ((((((status)::text = 'past_due'::text) AND (grace_ends_at IS NOT NULL)) OR (((status)::text <> 'past_due'::text) AND (grace_ends_at IS NULL))) AND ((((status)::text = 'canceled'::text) AND (access_expires_at IS NOT NULL)) OR (((status)::text <> 'canceled'::text) AND (access_expires_at IS NULL))))),
    CONSTRAINT subscriptions_cancellation_shape CHECK ((((cancel_at_period_end OR ((status)::text = 'canceled'::text)) AND (canceled_at IS NOT NULL)) OR (((status)::text = 'expired'::text) AND (NOT cancel_at_period_end)) OR ((NOT cancel_at_period_end) AND ((status)::text <> ALL (ARRAY[('canceled'::character varying)::text, ('expired'::character varying)::text])) AND (canceled_at IS NULL)))),
    CONSTRAINT subscriptions_interval_allowlist CHECK (((billing_interval)::text = ANY (ARRAY[('monthly'::character varying)::text, ('annual'::character varying)::text, ('custom'::character varying)::text]))),
    CONSTRAINT subscriptions_lifecycle_shape CHECK (((((status)::text = 'expired'::text) AND (ended_at IS NOT NULL)) OR (((status)::text <> 'expired'::text) AND (ended_at IS NULL)))),
    CONSTRAINT subscriptions_period_shape CHECK ((((current_period_starts_at IS NULL) AND (current_period_ends_at IS NULL)) OR ((current_period_ends_at IS NOT NULL) AND ((current_period_starts_at IS NULL) OR (current_period_ends_at > current_period_starts_at))))),
    CONSTRAINT subscriptions_provider_event_digest_format CHECK (((provider_event_digest IS NULL) OR ((provider_event_digest)::text ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT subscriptions_provider_event_precedence_nonnegative CHECK ((provider_event_precedence >= 0)),
    CONSTRAINT subscriptions_provider_metadata_bounded CHECK (((jsonb_typeof(provider_metadata) = 'object'::text) AND (pg_column_size(provider_metadata) <= 4096))),
    CONSTRAINT subscriptions_provider_shape CHECK ((((billing_customer_id IS NULL) AND (provider IS NULL) AND (provider_environment IS NULL) AND (provider_subscription_id IS NULL) AND (provider_updated_at IS NULL) AND (last_synced_at IS NULL) AND (provider_metadata = '{}'::jsonb)) OR ((billing_customer_id IS NOT NULL) AND (provider IS NOT NULL) AND (provider_environment IS NOT NULL) AND (provider_subscription_id IS NOT NULL) AND (provider_updated_at IS NOT NULL) AND (last_synced_at IS NOT NULL) AND (provider_metadata ? 'raw_status'::text)))),
    CONSTRAINT subscriptions_provider_sync_order CHECK (((last_synced_at IS NULL) OR (provider_updated_at IS NULL) OR (last_synced_at >= provider_updated_at))),
    CONSTRAINT subscriptions_snapshot_price_shape CHECK (((((pricing_kind_snapshot)::text = 'fixed'::text) AND ((billing_interval)::text = ANY (ARRAY[('monthly'::character varying)::text, ('annual'::character varying)::text])) AND (price_cents_snapshot IS NOT NULL) AND (price_cents_snapshot >= 0)) OR (((pricing_kind_snapshot)::text = 'custom'::text) AND ((billing_interval)::text = 'custom'::text) AND (price_cents_snapshot IS NULL)))),
    CONSTRAINT subscriptions_status_access_shape CHECK (((((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('incomplete'::character varying)::text])) AND ((access_state)::text = 'pending'::text)) OR (((status)::text = ANY (ARRAY[('trialing'::character varying)::text, ('active'::character varying)::text])) AND ((access_state)::text = 'full'::text)) OR (((status)::text = 'past_due'::text) AND ((access_state)::text = ANY (ARRAY[('grace'::character varying)::text, ('read_only'::character varying)::text]))) OR (((status)::text = 'paused'::text) AND ((access_state)::text = ANY (ARRAY[('read_only'::character varying)::text, ('suspended'::character varying)::text]))) OR (((status)::text = 'canceled'::text) AND ((access_state)::text = ANY (ARRAY[('full'::character varying)::text, ('read_only'::character varying)::text]))) OR (((status)::text = 'expired'::text) AND ((access_state)::text = 'read_only'::text)))),
    CONSTRAINT subscriptions_status_allowlist CHECK (((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('incomplete'::character varying)::text, ('trialing'::character varying)::text, ('active'::character varying)::text, ('past_due'::character varying)::text, ('paused'::character varying)::text, ('canceled'::character varying)::text, ('expired'::character varying)::text]))),
    CONSTRAINT subscriptions_trial_end_order CHECK (((trial_ends_at IS NULL) OR (trial_ends_at >= started_at)))
);


--
-- Name: team_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.team_memberships (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    added_at timestamp(6) with time zone NOT NULL,
    added_by_membership_id uuid NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    membership_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    removed_at timestamp(6) with time zone,
    team_id uuid NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT team_memberships_timestamp_order CHECK (((removed_at IS NULL) OR (removed_at >= added_at)))
);


--
-- Name: teams; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.teams (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    archived_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    name public.citext NOT NULL,
    organization_id uuid NOT NULL,
    status character varying(24) DEFAULT 'active'::character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT teams_lifecycle_consistency CHECK (((((status)::text = 'active'::text) AND (archived_at IS NULL)) OR (((status)::text = 'archived'::text) AND (archived_at IS NOT NULL)))),
    CONSTRAINT teams_name_format CHECK (((char_length((name)::text) >= 2) AND (char_length((name)::text) <= 120) AND ((name)::text = btrim((name)::text)))),
    CONSTRAINT teams_status_allowlist CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('archived'::character varying)::text])))
);


--
-- Name: usage_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usage_events (
    id bigint NOT NULL,
    organization_id uuid NOT NULL,
    source_organization_id uuid NOT NULL,
    usage_window_id uuid NOT NULL,
    usage_meter_definition_id uuid NOT NULL,
    usage_meter_rate_id uuid NOT NULL,
    idempotency_key_digest character varying(64) NOT NULL,
    request_checksum character varying(64) NOT NULL,
    event_kind character varying(24) NOT NULL,
    quantity numeric(24,6) NOT NULL,
    applied_weight numeric(18,6) NOT NULL,
    billed_quantity numeric(30,6) NOT NULL,
    source_type character varying(48) NOT NULL,
    source_id uuid NOT NULL,
    correction_of_event_id bigint,
    actor_membership_id uuid,
    reason_code character varying(64),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    occurred_at timestamp(6) with time zone NOT NULL,
    recorded_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT usage_events_digest_format CHECK ((((idempotency_key_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((request_checksum)::text ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT usage_events_kind_allowlist CHECK (((event_kind)::text = ANY (ARRAY[('usage'::character varying)::text, ('correction'::character varying)::text, ('manual_adjustment'::character varying)::text]))),
    CONSTRAINT usage_events_kind_shape CHECK (((((event_kind)::text = 'usage'::text) AND (quantity > (0)::numeric) AND (correction_of_event_id IS NULL) AND (actor_membership_id IS NULL) AND (reason_code IS NULL)) OR (((event_kind)::text = 'correction'::text) AND (quantity <> (0)::numeric) AND (correction_of_event_id IS NOT NULL) AND (reason_code IS NOT NULL)) OR (((event_kind)::text = 'manual_adjustment'::text) AND (quantity <> (0)::numeric) AND (correction_of_event_id IS NULL) AND (actor_membership_id IS NOT NULL) AND (reason_code IS NOT NULL)))),
    CONSTRAINT usage_events_metadata_bounded CHECK (((jsonb_typeof(metadata) = 'object'::text) AND (pg_column_size(metadata) <= 4096))),
    CONSTRAINT usage_events_reason_code_format CHECK (((reason_code IS NULL) OR ((reason_code)::text ~ '^[a-z][a-z0-9_]{1,63}$'::text))),
    CONSTRAINT usage_events_recording_order CHECK ((recorded_at >= occurred_at)),
    CONSTRAINT usage_events_source_tenant_match CHECK ((organization_id = source_organization_id)),
    CONSTRAINT usage_events_source_type_format CHECK (((source_type)::text ~ '^[A-Z][A-Za-z0-9]{0,47}$'::text)),
    CONSTRAINT usage_events_weighted_quantity CHECK (((applied_weight > (0)::numeric) AND (billed_quantity = (quantity * applied_weight))))
);


--
-- Name: usage_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.usage_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: usage_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.usage_events_id_seq OWNED BY public.usage_events.id;


--
-- Name: usage_meter_definitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usage_meter_definitions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key character varying(96) NOT NULL,
    name character varying(100) NOT NULL,
    unit character varying(32) NOT NULL,
    billing_unit character varying(32) NOT NULL,
    pool_key character varying(96) NOT NULL,
    quota_entitlement_key character varying(96),
    window_policy character varying(32) NOT NULL,
    description character varying(240) NOT NULL,
    catalog_checksum character varying(64) NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT usage_meter_definitions_checksum_format CHECK (((catalog_checksum)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT usage_meter_definitions_entitlement_format CHECK (((quota_entitlement_key IS NULL) OR ((quota_entitlement_key)::text ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'::text))),
    CONSTRAINT usage_meter_definitions_key_format CHECK ((((key)::text ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'::text) AND ((pool_key)::text ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'::text))),
    CONSTRAINT usage_meter_definitions_text_format CHECK (((char_length((name)::text) >= 3) AND (char_length((name)::text) <= 100) AND ((name)::text = btrim((name)::text)) AND ((char_length((description)::text) >= 3) AND (char_length((description)::text) <= 240)) AND ((description)::text = btrim((description)::text)))),
    CONSTRAINT usage_meter_definitions_unit_format CHECK ((((unit)::text ~ '^[a-z][a-z0-9_]{1,31}$'::text) AND ((billing_unit)::text ~ '^[a-z][a-z0-9_]{1,31}$'::text))),
    CONSTRAINT usage_meter_definitions_window_policy_allowlist CHECK (((window_policy)::text = ANY (ARRAY[('utc_calendar_month'::character varying)::text, ('provider_billing_period'::character varying)::text])))
);


--
-- Name: usage_meter_rates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usage_meter_rates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    usage_meter_definition_id uuid NOT NULL,
    version integer NOT NULL,
    weight numeric(18,6) NOT NULL,
    effective_at timestamp(6) with time zone NOT NULL,
    catalog_checksum character varying(64) NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT usage_meter_rates_checksum_format CHECK (((catalog_checksum)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT usage_meter_rates_positive_version CHECK ((version > 0)),
    CONSTRAINT usage_meter_rates_positive_weight CHECK ((weight > (0)::numeric))
);


--
-- Name: usage_quota_allocations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usage_quota_allocations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    usage_quota_reservation_id uuid NOT NULL,
    usage_window_id uuid NOT NULL,
    usage_meter_definition_id uuid NOT NULL,
    usage_meter_rate_id uuid NOT NULL,
    idempotency_key_digest character varying(64) NOT NULL,
    request_checksum character varying(64) NOT NULL,
    completion_key_digest character varying(64),
    completion_checksum character varying(64),
    state character varying(16) NOT NULL,
    quantity numeric(24,6) NOT NULL,
    applied_weight numeric(18,6) NOT NULL,
    billed_quantity numeric(30,6) NOT NULL,
    source_type character varying(48) NOT NULL,
    source_id uuid NOT NULL,
    usage_event_id bigint,
    allocated_at timestamp(6) with time zone NOT NULL,
    completed_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT usage_quota_allocations_digest_shape CHECK ((((idempotency_key_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((request_checksum)::text ~ '^[0-9a-f]{64}$'::text) AND ((completion_key_digest IS NULL) OR ((completion_key_digest)::text ~ '^[0-9a-f]{64}$'::text)) AND ((completion_checksum IS NULL) OR ((completion_checksum)::text ~ '^[0-9a-f]{64}$'::text)))),
    CONSTRAINT usage_quota_allocations_lifecycle_shape CHECK (((((state)::text = 'held'::text) AND (completion_key_digest IS NULL) AND (completion_checksum IS NULL) AND (usage_event_id IS NULL) AND (completed_at IS NULL)) OR (((state)::text = 'consumed'::text) AND (completion_key_digest IS NOT NULL) AND (completion_checksum IS NOT NULL) AND (usage_event_id IS NOT NULL) AND (completed_at IS NOT NULL)) OR (((state)::text = 'released'::text) AND (completion_key_digest IS NOT NULL) AND (completion_checksum IS NOT NULL) AND (usage_event_id IS NULL) AND (completed_at IS NOT NULL)))),
    CONSTRAINT usage_quota_allocations_source_type_format CHECK (((source_type)::text ~ '^[A-Z][A-Za-z0-9]{0,47}$'::text)),
    CONSTRAINT usage_quota_allocations_state_allowlist CHECK (((state)::text = ANY ((ARRAY['held'::character varying, 'consumed'::character varying, 'released'::character varying])::text[]))),
    CONSTRAINT usage_quota_allocations_weighted_quantity CHECK (((quantity > (0)::numeric) AND (applied_weight > (0)::numeric) AND (billed_quantity = (quantity * applied_weight))))
);


--
-- Name: usage_quota_reservation_operations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usage_quota_reservation_operations (
    id bigint NOT NULL,
    organization_id uuid NOT NULL,
    usage_quota_reservation_id uuid NOT NULL,
    operation_kind character varying(16) NOT NULL,
    idempotency_key_digest character varying(64) NOT NULL,
    request_checksum character varying(64) NOT NULL,
    quantity numeric(30,6) DEFAULT 0.0 NOT NULL,
    requested_expires_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    usage_event_id bigint,
    CONSTRAINT usage_quota_operations_digest_format CHECK ((((idempotency_key_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((request_checksum)::text ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT usage_quota_operations_event_shape CHECK ((((operation_kind)::text = 'finalize'::text) OR (usage_event_id IS NULL))),
    CONSTRAINT usage_quota_operations_kind_allowlist CHECK (((operation_kind)::text = ANY ((ARRAY['extend'::character varying, 'finalize'::character varying, 'release'::character varying, 'expire'::character varying])::text[]))),
    CONSTRAINT usage_quota_operations_quantity_nonnegative CHECK ((quantity >= (0)::numeric))
);


--
-- Name: usage_quota_reservation_operations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.usage_quota_reservation_operations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: usage_quota_reservation_operations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.usage_quota_reservation_operations_id_seq OWNED BY public.usage_quota_reservation_operations.id;


--
-- Name: usage_quota_reservations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usage_quota_reservations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    source_organization_id uuid NOT NULL,
    usage_window_id uuid NOT NULL,
    usage_meter_definition_id uuid NOT NULL,
    usage_meter_rate_id uuid NOT NULL,
    idempotency_key_digest character varying(64) NOT NULL,
    request_checksum character varying(64) NOT NULL,
    state character varying(16) NOT NULL,
    requested_quantity numeric(30,6) NOT NULL,
    held_quantity numeric(30,6) NOT NULL,
    consumed_quantity numeric(30,6) DEFAULT 0.0 NOT NULL,
    released_quantity numeric(30,6) DEFAULT 0.0 NOT NULL,
    source_type character varying(48) NOT NULL,
    source_id uuid NOT NULL,
    limit_kind character varying(16) NOT NULL,
    limit_quantity numeric(30,6),
    entitlement_key character varying(96),
    entitlement_state character varying(24) NOT NULL,
    entitlement_provenance character varying(32) NOT NULL,
    entitlement_definition_checksum character varying(64),
    entitlement_override_id uuid,
    subscription_id uuid,
    plan_version_id uuid,
    subscription_revision bigint,
    finalized_usage_event_id bigint,
    admitted_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    finalized_at timestamp(6) with time zone,
    released_at timestamp(6) with time zone,
    expired_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT usage_quota_reservations_digest_format CHECK ((((idempotency_key_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((request_checksum)::text ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT usage_quota_reservations_entitlement_provenance_format CHECK (((entitlement_provenance)::text ~ '^[a-z][a-z0-9_]{1,31}$'::text)),
    CONSTRAINT usage_quota_reservations_expiry_order CHECK ((expires_at > admitted_at)),
    CONSTRAINT usage_quota_reservations_lifecycle_shape CHECK (((((state)::text = 'held'::text) AND (released_quantity = (0)::numeric) AND (finalized_usage_event_id IS NULL) AND (finalized_at IS NULL) AND (released_at IS NULL) AND (expired_at IS NULL)) OR (((state)::text = 'finalized'::text) AND ((consumed_quantity + released_quantity) = held_quantity) AND (finalized_at IS NOT NULL) AND (released_at IS NULL) AND (expired_at IS NULL)) OR (((state)::text = 'released'::text) AND (consumed_quantity = (0)::numeric) AND (released_quantity = held_quantity) AND (finalized_usage_event_id IS NULL) AND (finalized_at IS NULL) AND (released_at IS NOT NULL) AND (expired_at IS NULL)) OR (((state)::text = 'expired'::text) AND ((consumed_quantity + released_quantity) = held_quantity) AND (finalized_usage_event_id IS NULL) AND (finalized_at IS NULL) AND (released_at IS NULL) AND (expired_at IS NOT NULL)))),
    CONSTRAINT usage_quota_reservations_limit_snapshot_shape CHECK (((((limit_kind)::text = 'unlimited'::text) AND (limit_quantity IS NULL) AND (entitlement_key IS NULL) AND ((entitlement_state)::text = 'unlimited'::text) AND (entitlement_definition_checksum IS NULL)) OR (((limit_kind)::text = 'capped'::text) AND (limit_quantity >= (0)::numeric) AND ((entitlement_key)::text ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'::text) AND ((entitlement_state)::text = ANY (ARRAY[('enabled'::character varying)::text, ('disabled'::character varying)::text])) AND ((entitlement_definition_checksum)::text ~ '^[0-9a-f]{64}$'::text)))),
    CONSTRAINT usage_quota_reservations_quantities_nonnegative CHECK (((requested_quantity > (0)::numeric) AND (held_quantity > (0)::numeric) AND (requested_quantity = held_quantity) AND (consumed_quantity >= (0)::numeric) AND (consumed_quantity <= held_quantity) AND (released_quantity >= (0)::numeric) AND (released_quantity <= held_quantity))),
    CONSTRAINT usage_quota_reservations_source_tenant_match CHECK ((organization_id = source_organization_id)),
    CONSTRAINT usage_quota_reservations_source_type_format CHECK (((source_type)::text ~ '^[A-Z][A-Za-z0-9]{0,47}$'::text)),
    CONSTRAINT usage_quota_reservations_state_allowlist CHECK (((state)::text = ANY (ARRAY[('held'::character varying)::text, ('finalized'::character varying)::text, ('released'::character varying)::text, ('expired'::character varying)::text]))),
    CONSTRAINT usage_quota_reservations_subscription_snapshot_shape CHECK ((((subscription_id IS NULL) AND (subscription_revision IS NULL)) OR ((subscription_id IS NOT NULL) AND (plan_version_id IS NOT NULL) AND (subscription_revision >= 0))))
);


--
-- Name: usage_windows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usage_windows (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    usage_meter_definition_id uuid NOT NULL,
    starts_at timestamp(6) with time zone NOT NULL,
    ends_at timestamp(6) with time zone NOT NULL,
    window_policy character varying(32) NOT NULL,
    time_zone_name character varying(64) NOT NULL,
    period_reference_digest character varying(64),
    subscription_id uuid,
    plan_version_id uuid,
    subscription_revision bigint,
    created_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT usage_windows_period_reference_shape CHECK (((((window_policy)::text = 'utc_calendar_month'::text) AND ((time_zone_name)::text = 'UTC'::text) AND (period_reference_digest IS NULL)) OR (((window_policy)::text = 'provider_billing_period'::text) AND ((period_reference_digest)::text ~ '^[0-9a-f]{64}$'::text)))),
    CONSTRAINT usage_windows_policy_allowlist CHECK (((window_policy)::text = ANY (ARRAY[('utc_calendar_month'::character varying)::text, ('provider_billing_period'::character varying)::text]))),
    CONSTRAINT usage_windows_positive_period CHECK ((ends_at > starts_at)),
    CONSTRAINT usage_windows_subscription_context_shape CHECK ((((subscription_id IS NULL) AND (plan_version_id IS NULL) AND (subscription_revision IS NULL)) OR ((subscription_id IS NOT NULL) AND (plan_version_id IS NOT NULL) AND (subscription_revision >= 0)))),
    CONSTRAINT usage_windows_time_zone_format CHECK (((char_length((time_zone_name)::text) >= 1) AND (char_length((time_zone_name)::text) <= 64) AND ((time_zone_name)::text = btrim((time_zone_name)::text))))
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    accepted_terms_at timestamp(6) with time zone,
    avatar_url text,
    created_at timestamp(6) with time zone NOT NULL,
    deleted_at timestamp(6) with time zone,
    display_name character varying,
    locale character varying DEFAULT 'en'::character varying NOT NULL,
    primary_email public.citext,
    suspended_at timestamp(6) with time zone,
    time_zone character varying DEFAULT 'UTC'::character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT users_locale_length CHECK (((char_length((locale)::text) >= 2) AND (char_length((locale)::text) <= 16))),
    CONSTRAINT users_normalized_email CHECK (((primary_email IS NULL) OR ((char_length((primary_email)::text) >= 3) AND (char_length((primary_email)::text) <= 320) AND ((primary_email)::text = lower((primary_email)::text))))),
    CONSTRAINT users_time_zone_length CHECK (((char_length((time_zone)::text) >= 1) AND (char_length((time_zone)::text) <= 64)))
);


--
-- Name: website_property_configs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.website_property_configs (
    property_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    property_kind character varying(32) NOT NULL,
    configuration_version integer DEFAULT 1 NOT NULL,
    scheme character varying(8) NOT NULL,
    host public.citext NOT NULL,
    port integer NOT NULL,
    origin text NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT website_configs_canonical_origin CHECK (((char_length(origin) >= 8) AND (char_length(origin) <= 2048) AND (origin = ((((scheme)::text || '://'::text) || lower((host)::text)) ||
CASE
    WHEN ((((scheme)::text = 'http'::text) AND (port = 80)) OR (((scheme)::text = 'https'::text) AND (port = 443))) THEN ''::text
    ELSE (':'::text || (port)::text)
END)))),
    CONSTRAINT website_configs_host_format CHECK ((((host)::text = lower((host)::text)) AND ((host)::text ~ '^[a-z0-9](?:[a-z0-9.-]{0,251}[a-z0-9])?$'::text))),
    CONSTRAINT website_configs_transport CHECK ((((scheme)::text = ANY (ARRAY[('http'::character varying)::text, ('https'::character varying)::text])) AND ((port >= 1) AND (port <= 65535)))),
    CONSTRAINT website_configs_type_and_version CHECK ((((property_kind)::text = ANY (ARRAY[('website'::character varying)::text, ('web_application'::character varying)::text])) AND (configuration_version = 1)))
);


--
-- Name: authentication_rate_limit_buckets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authentication_rate_limit_buckets ALTER COLUMN id SET DEFAULT nextval('public.authentication_rate_limit_buckets_id_seq'::regclass);


--
-- Name: crawl_fetch_results id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_fetch_results ALTER COLUMN id SET DEFAULT nextval('public.crawl_fetch_results_id_seq'::regclass);


--
-- Name: crawl_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_links ALTER COLUMN id SET DEFAULT nextval('public.crawl_links_id_seq'::regclass);


--
-- Name: crawl_page_facts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_page_facts ALTER COLUMN id SET DEFAULT nextval('public.crawl_page_facts_id_seq'::regclass);


--
-- Name: crawl_page_renders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_page_renders ALTER COLUMN id SET DEFAULT nextval('public.crawl_page_renders_id_seq'::regclass);


--
-- Name: crawl_page_snapshots id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_page_snapshots ALTER COLUMN id SET DEFAULT nextval('public.crawl_page_snapshots_id_seq'::regclass);


--
-- Name: crawl_rendered_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_rendered_links ALTER COLUMN id SET DEFAULT nextval('public.crawl_rendered_links_id_seq'::regclass);


--
-- Name: crawl_rendered_page_facts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_rendered_page_facts ALTER COLUMN id SET DEFAULT nextval('public.crawl_rendered_page_facts_id_seq'::regclass);


--
-- Name: crawl_scan_usage_operations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_scan_usage_operations ALTER COLUMN id SET DEFAULT nextval('public.crawl_scan_usage_operations_id_seq'::regclass);


--
-- Name: crawl_sitemap_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_sitemap_entries ALTER COLUMN id SET DEFAULT nextval('public.crawl_sitemap_entries_id_seq'::regclass);


--
-- Name: crawl_urls id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_urls ALTER COLUMN id SET DEFAULT nextval('public.crawl_urls_id_seq'::regclass);


--
-- Name: scan_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scan_events ALTER COLUMN id SET DEFAULT nextval('public.scan_events_id_seq'::regclass);


--
-- Name: usage_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_events ALTER COLUMN id SET DEFAULT nextval('public.usage_events_id_seq'::regclass);


--
-- Name: usage_quota_reservation_operations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_quota_reservation_operations ALTER COLUMN id SET DEFAULT nextval('public.usage_quota_reservation_operations_id_seq'::regclass);


--
-- Name: android_property_configs android_property_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.android_property_configs
    ADD CONSTRAINT android_property_configs_pkey PRIMARY KEY (property_id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: artifact_blobs artifact_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artifact_blobs
    ADD CONSTRAINT artifact_blobs_pkey PRIMARY KEY (id);


--
-- Name: artifacts artifacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artifacts
    ADD CONSTRAINT artifacts_pkey PRIMARY KEY (id);


--
-- Name: audit_events audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_pkey PRIMARY KEY (id);


--
-- Name: audit_target_tombstones audit_target_tombstones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_target_tombstones
    ADD CONSTRAINT audit_target_tombstones_pkey PRIMARY KEY (id);


--
-- Name: authentication_rate_limit_buckets authentication_rate_limit_buckets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authentication_rate_limit_buckets
    ADD CONSTRAINT authentication_rate_limit_buckets_pkey PRIMARY KEY (id);


--
-- Name: authorization_catalog_revisions authorization_catalog_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authorization_catalog_revisions
    ADD CONSTRAINT authorization_catalog_revisions_pkey PRIMARY KEY (id);


--
-- Name: authorization_scope_references authorization_scope_references_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authorization_scope_references
    ADD CONSTRAINT authorization_scope_references_pkey PRIMARY KEY (id);


--
-- Name: billing_checkout_sessions billing_checkout_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_checkout_sessions
    ADD CONSTRAINT billing_checkout_sessions_pkey PRIMARY KEY (id);


--
-- Name: billing_customers billing_customers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_customers
    ADD CONSTRAINT billing_customers_pkey PRIMARY KEY (id);


--
-- Name: billing_plan_provider_mappings billing_plan_provider_mappings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_plan_provider_mappings
    ADD CONSTRAINT billing_plan_provider_mappings_pkey PRIMARY KEY (id);


--
-- Name: billing_reconciliation_runs billing_reconciliation_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_reconciliation_runs
    ADD CONSTRAINT billing_reconciliation_runs_pkey PRIMARY KEY (id);


--
-- Name: billing_subscription_changes billing_subscription_changes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_subscription_changes
    ADD CONSTRAINT billing_subscription_changes_pkey PRIMARY KEY (id);


--
-- Name: billing_support_access_grants billing_support_access_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_support_access_grants
    ADD CONSTRAINT billing_support_access_grants_pkey PRIMARY KEY (id);


--
-- Name: billing_webhook_events billing_webhook_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_webhook_events
    ADD CONSTRAINT billing_webhook_events_pkey PRIMARY KEY (id);


--
-- Name: crawl_control_access_grants crawl_control_access_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_control_access_grants
    ADD CONSTRAINT crawl_control_access_grants_pkey PRIMARY KEY (id);


--
-- Name: crawl_fetch_permits crawl_fetch_permits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_fetch_permits
    ADD CONSTRAINT crawl_fetch_permits_pkey PRIMARY KEY (id);


--
-- Name: crawl_fetch_results crawl_fetch_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_fetch_results
    ADD CONSTRAINT crawl_fetch_results_pkey PRIMARY KEY (id);


--
-- Name: crawl_links crawl_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_links
    ADD CONSTRAINT crawl_links_pkey PRIMARY KEY (id);


--
-- Name: crawl_page_facts crawl_page_facts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_page_facts
    ADD CONSTRAINT crawl_page_facts_pkey PRIMARY KEY (id);


--
-- Name: crawl_page_renders crawl_page_renders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_page_renders
    ADD CONSTRAINT crawl_page_renders_pkey PRIMARY KEY (id);


--
-- Name: crawl_page_snapshots crawl_page_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_page_snapshots
    ADD CONSTRAINT crawl_page_snapshots_pkey PRIMARY KEY (id);


--
-- Name: crawl_policy_sets crawl_policy_sets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_policy_sets
    ADD CONSTRAINT crawl_policy_sets_pkey PRIMARY KEY (id);


--
-- Name: crawl_policy_snapshots crawl_policy_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_policy_snapshots
    ADD CONSTRAINT crawl_policy_snapshots_pkey PRIMARY KEY (id);


--
-- Name: crawl_policy_versions crawl_policy_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_policy_versions
    ADD CONSTRAINT crawl_policy_versions_pkey PRIMARY KEY (id);


--
-- Name: crawl_pressure_states crawl_pressure_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_pressure_states
    ADD CONSTRAINT crawl_pressure_states_pkey PRIMARY KEY (id);


--
-- Name: crawl_rendered_links crawl_rendered_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_rendered_links
    ADD CONSTRAINT crawl_rendered_links_pkey PRIMARY KEY (id);


--
-- Name: crawl_rendered_page_facts crawl_rendered_page_facts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_rendered_page_facts
    ADD CONSTRAINT crawl_rendered_page_facts_pkey PRIMARY KEY (id);


--
-- Name: crawl_robots_snapshots crawl_robots_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_robots_snapshots
    ADD CONSTRAINT crawl_robots_snapshots_pkey PRIMARY KEY (id);


--
-- Name: crawl_scan_executions crawl_scan_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_scan_executions
    ADD CONSTRAINT crawl_scan_executions_pkey PRIMARY KEY (id);


--
-- Name: crawl_scan_usage_operations crawl_scan_usage_operations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_scan_usage_operations
    ADD CONSTRAINT crawl_scan_usage_operations_pkey PRIMARY KEY (id);


--
-- Name: crawl_sitemap_discoveries crawl_sitemap_discoveries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_sitemap_discoveries
    ADD CONSTRAINT crawl_sitemap_discoveries_pkey PRIMARY KEY (id);


--
-- Name: crawl_sitemap_entries crawl_sitemap_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_sitemap_entries
    ADD CONSTRAINT crawl_sitemap_entries_pkey PRIMARY KEY (id);


--
-- Name: crawl_sitemap_files crawl_sitemap_files_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_sitemap_files
    ADD CONSTRAINT crawl_sitemap_files_pkey PRIMARY KEY (id);


--
-- Name: crawl_urls crawl_urls_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_urls
    ADD CONSTRAINT crawl_urls_pkey PRIMARY KEY (id);


--
-- Name: domain_verification_attempts domain_verification_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_verification_attempts
    ADD CONSTRAINT domain_verification_attempts_pkey PRIMARY KEY (id);


--
-- Name: domain_verifications domain_verifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_verifications
    ADD CONSTRAINT domain_verifications_pkey PRIMARY KEY (id);


--
-- Name: entitlement_definitions entitlement_definitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entitlement_definitions
    ADD CONSTRAINT entitlement_definitions_pkey PRIMARY KEY (id);


--
-- Name: entitlement_subscription_contexts entitlement_subscription_contexts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entitlement_subscription_contexts
    ADD CONSTRAINT entitlement_subscription_contexts_pkey PRIMARY KEY (id);


--
-- Name: identities identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identities
    ADD CONSTRAINT identities_pkey PRIMARY KEY (id);


--
-- Name: integration_connections integration_connections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_connections
    ADD CONSTRAINT integration_connections_pkey PRIMARY KEY (id);


--
-- Name: invitations invitations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT invitations_pkey PRIMARY KEY (id);


--
-- Name: ios_property_configs ios_property_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ios_property_configs
    ADD CONSTRAINT ios_property_configs_pkey PRIMARY KEY (property_id);


--
-- Name: memberships memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_pkey PRIMARY KEY (id);


--
-- Name: oauth_transactions oauth_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_transactions
    ADD CONSTRAINT oauth_transactions_pkey PRIMARY KEY (id);


--
-- Name: organization_entitlement_overrides organization_entitlement_overrides_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_entitlement_overrides
    ADD CONSTRAINT organization_entitlement_overrides_pkey PRIMARY KEY (id);


--
-- Name: organization_ownerships organization_ownerships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_ownerships
    ADD CONSTRAINT organization_ownerships_pkey PRIMARY KEY (id);


--
-- Name: organization_slug_aliases organization_slug_aliases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_slug_aliases
    ADD CONSTRAINT organization_slug_aliases_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: outbox_events outbox_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.outbox_events
    ADD CONSTRAINT outbox_events_pkey PRIMARY KEY (id);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: plan_catalog_access_grants plan_catalog_access_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plan_catalog_access_grants
    ADD CONSTRAINT plan_catalog_access_grants_pkey PRIMARY KEY (id);


--
-- Name: plan_entitlements plan_entitlements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plan_entitlements
    ADD CONSTRAINT plan_entitlements_pkey PRIMARY KEY (id);


--
-- Name: plan_version_snapshot_references plan_version_snapshot_references_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plan_version_snapshot_references
    ADD CONSTRAINT plan_version_snapshot_references_pkey PRIMARY KEY (id);


--
-- Name: plan_versions plan_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plan_versions
    ADD CONSTRAINT plan_versions_pkey PRIMARY KEY (id);


--
-- Name: plans plans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plans
    ADD CONSTRAINT plans_pkey PRIMARY KEY (id);


--
-- Name: project_onboarding_drafts project_onboarding_drafts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_onboarding_drafts
    ADD CONSTRAINT project_onboarding_drafts_pkey PRIMARY KEY (id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: properties properties_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.properties
    ADD CONSTRAINT properties_pkey PRIMARY KEY (id);


--
-- Name: property_environments property_environments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.property_environments
    ADD CONSTRAINT property_environments_pkey PRIMARY KEY (id);


--
-- Name: resource_deletion_stage_executions resource_deletion_stage_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_deletion_stage_executions
    ADD CONSTRAINT resource_deletion_stage_executions_pkey PRIMARY KEY (id);


--
-- Name: resource_deletion_workflows resource_deletion_workflows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_deletion_workflows
    ADD CONSTRAINT resource_deletion_workflows_pkey PRIMARY KEY (id);


--
-- Name: role_assignments role_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT role_assignments_pkey PRIMARY KEY (id);


--
-- Name: role_permissions role_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_pkey PRIMARY KEY (id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: scan_events scan_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scan_events
    ADD CONSTRAINT scan_events_pkey PRIMARY KEY (id);


--
-- Name: scans scans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scans
    ADD CONSTRAINT scans_pkey PRIMARY KEY (id);


--
-- Name: scans scans_throttle_observation_shape; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.scans
    ADD CONSTRAINT scans_throttle_observation_shape CHECK ((((throttled_at IS NULL) AND (throttle_reason IS NULL) AND (throttle_until IS NULL)) OR ((throttled_at IS NOT NULL) AND ((throttle_reason)::text ~ '^[a-z][a-z0-9_]{0,63}$'::text) AND ((throttle_until IS NULL) OR (throttle_until >= throttled_at))))) NOT VALID;


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: subscriptions subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (id);


--
-- Name: team_memberships team_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_memberships
    ADD CONSTRAINT team_memberships_pkey PRIMARY KEY (id);


--
-- Name: teams teams_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_pkey PRIMARY KEY (id);


--
-- Name: usage_events usage_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_events
    ADD CONSTRAINT usage_events_pkey PRIMARY KEY (id);


--
-- Name: usage_meter_definitions usage_meter_definitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_meter_definitions
    ADD CONSTRAINT usage_meter_definitions_pkey PRIMARY KEY (id);


--
-- Name: usage_meter_rates usage_meter_rates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_meter_rates
    ADD CONSTRAINT usage_meter_rates_pkey PRIMARY KEY (id);


--
-- Name: usage_quota_allocations usage_quota_allocations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_quota_allocations
    ADD CONSTRAINT usage_quota_allocations_pkey PRIMARY KEY (id);


--
-- Name: usage_quota_reservation_operations usage_quota_reservation_operations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_quota_reservation_operations
    ADD CONSTRAINT usage_quota_reservation_operations_pkey PRIMARY KEY (id);


--
-- Name: usage_quota_reservations usage_quota_reservations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_quota_reservations
    ADD CONSTRAINT usage_quota_reservations_pkey PRIMARY KEY (id);


--
-- Name: usage_windows usage_windows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_windows
    ADD CONSTRAINT usage_windows_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: website_property_configs website_property_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.website_property_configs
    ADD CONSTRAINT website_property_configs_pkey PRIMARY KEY (property_id);


--
-- Name: index_android_configs_on_normalized_package; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_android_configs_on_normalized_package ON public.android_property_configs USING btree (organization_id, project_id, package_name);


--
-- Name: index_artifact_blobs_on_exact_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_artifact_blobs_on_exact_identity ON public.artifact_blobs USING btree (organization_id, project_id, property_id, id);


--
-- Name: index_artifact_blobs_on_reconciliation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_artifact_blobs_on_reconciliation ON public.artifact_blobs USING btree (state, updated_at, id);


--
-- Name: index_artifact_blobs_on_safe_deduplication; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_artifact_blobs_on_safe_deduplication ON public.artifact_blobs USING btree (organization_id, project_id, property_id, encryption_key_version, content_sha256) WHERE ((state)::text <> 'deleted'::text);


--
-- Name: index_artifacts_on_blob_retention; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_artifacts_on_blob_retention ON public.artifacts USING btree (artifact_blob_id, retention_state, legal_hold);


--
-- Name: index_artifacts_on_exact_scan_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_artifacts_on_exact_scan_identity ON public.artifacts USING btree (organization_id, project_id, property_id, environment_id, scan_id, id);


--
-- Name: index_artifacts_on_retention_queue; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_artifacts_on_retention_queue ON public.artifacts USING btree (retention_state, legal_hold, retention_expires_at, id);


--
-- Name: index_artifacts_on_source_idempotency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_artifacts_on_source_idempotency ON public.artifacts USING btree (organization_id, project_id, property_id, source_type, source_id, kind);


--
-- Name: index_artifacts_on_tenant_scan; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_artifacts_on_tenant_scan ON public.artifacts USING btree (organization_id, project_id, property_id, scan_id, id);


--
-- Name: index_audit_events_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_job_id ON public.audit_events USING btree (job_id) WHERE (job_id IS NOT NULL);


--
-- Name: index_audit_events_on_org_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_org_action ON public.audit_events USING btree (organization_id, action, occurred_at DESC);


--
-- Name: index_audit_events_on_org_actor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_org_actor ON public.audit_events USING btree (organization_id, actor_membership_id, occurred_at DESC);


--
-- Name: index_audit_events_on_org_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_org_target ON public.audit_events USING btree (organization_id, target_type, target_id, occurred_at DESC);


--
-- Name: index_audit_events_on_org_timeline; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_org_timeline ON public.audit_events USING btree (organization_id, occurred_at DESC, id DESC);


--
-- Name: index_audit_events_on_request_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_request_id ON public.audit_events USING btree (request_id) WHERE (request_id IS NOT NULL);


--
-- Name: index_audit_tombstones_on_resource_hierarchy; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_tombstones_on_resource_hierarchy ON public.audit_target_tombstones USING btree (organization_id, project_id, property_id);


--
-- Name: index_audit_tombstones_on_target; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_audit_tombstones_on_target ON public.audit_target_tombstones USING btree (organization_id, target_type, target_id);


--
-- Name: index_auth_rate_limits_on_expiry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_auth_rate_limits_on_expiry ON public.authentication_rate_limit_buckets USING btree (expires_at);


--
-- Name: index_auth_rate_limits_on_scope_key_and_window; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_auth_rate_limits_on_scope_key_and_window ON public.authentication_rate_limit_buckets USING btree (scope, key_digest, window_started_at);


--
-- Name: index_authorization_catalog_revisions_on_checksum; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_authorization_catalog_revisions_on_checksum ON public.authorization_catalog_revisions USING btree (checksum);


--
-- Name: index_authorization_scopes_on_org_and_project; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_authorization_scopes_on_org_and_project ON public.authorization_scope_references USING btree (organization_id, project_id);


--
-- Name: index_authorization_scopes_on_org_id_and_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_authorization_scopes_on_org_id_and_type ON public.authorization_scope_references USING btree (organization_id, id, scope_type);


--
-- Name: index_authorization_scopes_on_property_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_authorization_scopes_on_property_identity ON public.authorization_scope_references USING btree (organization_id, id, scope_type, project_id, project_scope_type);


--
-- Name: index_billing_changes_on_active_subscription; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_billing_changes_on_active_subscription ON public.billing_subscription_changes USING btree (subscription_id) WHERE ((state)::text = ANY (ARRAY[('pending'::character varying)::text, ('scheduled'::character varying)::text, ('submitted'::character varying)::text]));


--
-- Name: index_billing_changes_on_dispatch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_billing_changes_on_dispatch ON public.billing_subscription_changes USING btree (state, effective_at);


--
-- Name: index_billing_changes_on_tenant_idempotency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_billing_changes_on_tenant_idempotency ON public.billing_subscription_changes USING btree (organization_id, idempotency_digest);


--
-- Name: index_billing_checkouts_on_active_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_billing_checkouts_on_active_tenant ON public.billing_checkout_sessions USING btree (organization_id) WHERE ((state)::text = ANY (ARRAY[('preparing'::character varying)::text, ('ready'::character varying)::text, ('uncertain'::character varying)::text]));


--
-- Name: index_billing_checkouts_on_provider_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_billing_checkouts_on_provider_identity ON public.billing_checkout_sessions USING btree (provider, environment, provider_checkout_id) WHERE (provider_checkout_id IS NOT NULL);


--
-- Name: index_billing_checkouts_on_tenant_idempotency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_billing_checkouts_on_tenant_idempotency ON public.billing_checkout_sessions USING btree (organization_id, idempotency_digest);


--
-- Name: index_billing_checkouts_on_tenant_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_billing_checkouts_on_tenant_identity ON public.billing_checkout_sessions USING btree (organization_id, id);


--
-- Name: index_billing_customers_on_composite_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_billing_customers_on_composite_identity ON public.billing_customers USING btree (id, organization_id, provider, environment);


--
-- Name: index_billing_customers_on_provider_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_billing_customers_on_provider_identity ON public.billing_customers USING btree (provider, environment, provider_customer_id);


--
-- Name: index_billing_customers_on_tenant_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_billing_customers_on_tenant_provider ON public.billing_customers USING btree (organization_id, provider, environment);


--
-- Name: index_billing_plan_mappings_on_active_target; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_billing_plan_mappings_on_active_target ON public.billing_plan_provider_mappings USING btree (plan_version_id, provider, environment, currency, billing_interval) WHERE (active = true);


--
-- Name: index_billing_plan_mappings_on_provider_catalog_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_billing_plan_mappings_on_provider_catalog_identity ON public.billing_plan_provider_mappings USING btree (provider, environment, provider_store_id, provider_product_id, provider_variant_id) WHERE ((provider_store_id IS NOT NULL) AND (provider_product_id IS NOT NULL));


--
-- Name: index_billing_plan_mappings_on_provider_variant; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_billing_plan_mappings_on_provider_variant ON public.billing_plan_provider_mappings USING btree (provider, environment, provider_variant_id);


--
-- Name: index_billing_reconciliations_on_active_subscription; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_billing_reconciliations_on_active_subscription ON public.billing_reconciliation_runs USING btree (subscription_id) WHERE ((state)::text = ANY (ARRAY[('queued'::character varying)::text, ('running'::character varying)::text, ('retryable'::character varying)::text]));


--
-- Name: index_billing_reconciliations_on_provider_rate; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_billing_reconciliations_on_provider_rate ON public.billing_reconciliation_runs USING btree (provider, environment, requested_at);


--
-- Name: index_billing_reconciliations_on_retry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_billing_reconciliations_on_retry ON public.billing_reconciliation_runs USING btree (state, next_attempt_at);


--
-- Name: index_billing_reconciliations_on_tenant_history; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_billing_reconciliations_on_tenant_history ON public.billing_reconciliation_runs USING btree (organization_id, requested_at);


--
-- Name: index_billing_support_grants_on_active_permission; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_billing_support_grants_on_active_permission ON public.billing_support_access_grants USING btree (user_id, permission) WHERE (revoked_at IS NULL);


--
-- Name: index_billing_webhooks_on_payload_checksum; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_billing_webhooks_on_payload_checksum ON public.billing_webhook_events USING btree (payload_checksum);


--
-- Name: index_billing_webhooks_on_provider_event; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_billing_webhooks_on_provider_event ON public.billing_webhook_events USING btree (provider, environment, provider_event_id);


--
-- Name: index_billing_webhooks_on_retry_schedule; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_billing_webhooks_on_retry_schedule ON public.billing_webhook_events USING btree (state, next_attempt_at);


--
-- Name: index_billing_webhooks_on_state_received; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_billing_webhooks_on_state_received ON public.billing_webhook_events USING btree (state, received_at);


--
-- Name: index_billing_webhooks_on_tenant_received; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_billing_webhooks_on_tenant_received ON public.billing_webhook_events USING btree (organization_id, received_at);


--
-- Name: index_crawl_control_grants_on_active_permission; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_control_grants_on_active_permission ON public.crawl_control_access_grants USING btree (user_id, permission) WHERE (revoked_at IS NULL);


--
-- Name: index_crawl_fetch_permits_on_active_expiry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_fetch_permits_on_active_expiry ON public.crawl_fetch_permits USING btree (state, expires_at, id) WHERE ((state)::text = 'active'::text);


--
-- Name: index_crawl_fetch_permits_on_active_frontier; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_fetch_permits_on_active_frontier ON public.crawl_fetch_permits USING btree (crawl_url_id) WHERE ((state)::text = 'active'::text);


--
-- Name: index_crawl_fetch_permits_on_active_host; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_fetch_permits_on_active_host ON public.crawl_fetch_permits USING btree (host_key_digest, state, expires_at) WHERE ((state)::text = 'active'::text);


--
-- Name: index_crawl_fetch_permits_on_active_organization; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_fetch_permits_on_active_organization ON public.crawl_fetch_permits USING btree (organization_id, state, expires_at) WHERE ((state)::text = 'active'::text);


--
-- Name: index_crawl_fetch_permits_on_active_scan; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_fetch_permits_on_active_scan ON public.crawl_fetch_permits USING btree (scan_id, state, expires_at) WHERE ((state)::text = 'active'::text);


--
-- Name: index_crawl_fetch_results_on_scan_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_fetch_results_on_scan_and_id ON public.crawl_fetch_results USING btree (scan_id, id);


--
-- Name: index_crawl_fetch_results_on_source; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_fetch_results_on_source ON public.crawl_fetch_results USING btree (scan_id, source_key_digest);


--
-- Name: index_crawl_fetch_results_on_tenant_scan_outcome; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_fetch_results_on_tenant_scan_outcome ON public.crawl_fetch_results USING btree (organization_id, scan_id, outcome, id);


--
-- Name: index_crawl_fetch_results_on_url_attempt; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_fetch_results_on_url_attempt ON public.crawl_fetch_results USING btree (scan_id, crawl_url_id, attempt_number);


--
-- Name: index_crawl_links_on_internal_destination; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_links_on_internal_destination ON public.crawl_links USING btree (scan_id, destination_crawl_url_id, source_crawl_url_id) WHERE (((classification)::text = 'internal'::text) AND (destination_crawl_url_id IS NOT NULL));


--
-- Name: index_crawl_links_on_scan_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_links_on_scan_source ON public.crawl_links USING btree (scan_id, source_crawl_url_id, id);


--
-- Name: index_crawl_links_on_snapshot_destination; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_links_on_snapshot_destination ON public.crawl_links USING btree (page_snapshot_id, destination_url_digest);


--
-- Name: index_crawl_links_on_tenant_scan_classification; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_links_on_tenant_scan_classification ON public.crawl_links USING btree (organization_id, scan_id, classification, id);


--
-- Name: index_crawl_page_facts_on_exact_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_page_facts_on_exact_identity ON public.crawl_page_facts USING btree (organization_id, project_id, property_id, environment_id, scan_id, id);


--
-- Name: index_crawl_page_facts_on_page_snapshot_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_page_facts_on_page_snapshot_id ON public.crawl_page_facts USING btree (page_snapshot_id);


--
-- Name: index_crawl_page_facts_on_scan_title; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_page_facts_on_scan_title ON public.crawl_page_facts USING btree (scan_id, title_digest) WHERE (title_digest IS NOT NULL);


--
-- Name: index_crawl_page_facts_on_tenant_scan_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_page_facts_on_tenant_scan_status ON public.crawl_page_facts USING btree (organization_id, scan_id, parse_status, id);


--
-- Name: index_crawl_page_renders_on_exact_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_page_renders_on_exact_identity ON public.crawl_page_renders USING btree (organization_id, project_id, property_id, environment_id, scan_id, id);


--
-- Name: index_crawl_page_renders_on_page_snapshot_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_page_renders_on_page_snapshot_id ON public.crawl_page_renders USING btree (page_snapshot_id);


--
-- Name: index_crawl_page_renders_on_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_page_renders_on_pending ON public.crawl_page_renders USING btree (state, next_attempt_at, id) WHERE ((state)::text = 'pending'::text);


--
-- Name: index_crawl_page_renders_on_recovery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_page_renders_on_recovery ON public.crawl_page_renders USING btree (state, lease_expires_at, id) WHERE ((state)::text = 'processing'::text);


--
-- Name: index_crawl_page_renders_on_tenant_scan_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_page_renders_on_tenant_scan_state ON public.crawl_page_renders USING btree (organization_id, scan_id, state, id);


--
-- Name: index_crawl_page_snapshots_on_exact_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_page_snapshots_on_exact_identity ON public.crawl_page_snapshots USING btree (organization_id, project_id, property_id, environment_id, scan_id, id);


--
-- Name: index_crawl_page_snapshots_on_recovery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_page_snapshots_on_recovery ON public.crawl_page_snapshots USING btree (state, extraction_lease_expires_at, id);


--
-- Name: index_crawl_page_snapshots_on_scan_fetch; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_page_snapshots_on_scan_fetch ON public.crawl_page_snapshots USING btree (scan_id, crawl_fetch_result_id);


--
-- Name: index_crawl_page_snapshots_on_scan_url; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_page_snapshots_on_scan_url ON public.crawl_page_snapshots USING btree (scan_id, crawl_url_id);


--
-- Name: index_crawl_page_snapshots_on_work_queue; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_page_snapshots_on_work_queue ON public.crawl_page_snapshots USING btree (state, next_attempt_at, id);


--
-- Name: index_crawl_policy_sets_on_environment; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_policy_sets_on_environment ON public.crawl_policy_sets USING btree (organization_id, project_id, property_id, environment_id);


--
-- Name: index_crawl_policy_sets_on_tenant_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_policy_sets_on_tenant_identity ON public.crawl_policy_sets USING btree (id, organization_id, project_id, property_id, environment_id);


--
-- Name: index_crawl_policy_snapshots_on_scan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_policy_snapshots_on_scan_id ON public.crawl_policy_snapshots USING btree (scan_id);


--
-- Name: index_crawl_policy_snapshots_on_tenant_scan; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_policy_snapshots_on_tenant_scan ON public.crawl_policy_snapshots USING btree (organization_id, scan_id);


--
-- Name: index_crawl_policy_versions_on_environment_version; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_policy_versions_on_environment_version ON public.crawl_policy_versions USING btree (organization_id, project_id, property_id, environment_id, version);


--
-- Name: index_crawl_policy_versions_on_sequence; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_policy_versions_on_sequence ON public.crawl_policy_versions USING btree (crawl_policy_set_id, version);


--
-- Name: index_crawl_policy_versions_on_tenant_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_policy_versions_on_tenant_identity ON public.crawl_policy_versions USING btree (organization_id, project_id, property_id, environment_id, id);


--
-- Name: index_crawl_pressure_states_on_backoff; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_pressure_states_on_backoff ON public.crawl_pressure_states USING btree (backoff_until, id) WHERE (backoff_until IS NOT NULL);


--
-- Name: index_crawl_pressure_states_on_disabled; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_pressure_states_on_disabled ON public.crawl_pressure_states USING btree (scope_type, disabled_at, id) WHERE (disabled_at IS NOT NULL);


--
-- Name: index_crawl_pressure_states_on_scope_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_pressure_states_on_scope_key ON public.crawl_pressure_states USING btree (scope_type, scope_key_digest);


--
-- Name: index_crawl_pressure_states_on_tenant_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_pressure_states_on_tenant_scope ON public.crawl_pressure_states USING btree (organization_id, scope_type) WHERE (organization_id IS NOT NULL);


--
-- Name: index_crawl_rendered_facts_on_tenant_scan_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_rendered_facts_on_tenant_scan_status ON public.crawl_rendered_page_facts USING btree (organization_id, scan_id, parse_status, id);


--
-- Name: index_crawl_rendered_links_on_render_destination; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_rendered_links_on_render_destination ON public.crawl_rendered_links USING btree (page_render_id, destination_url_digest);


--
-- Name: index_crawl_rendered_links_on_tenant_scan_classification; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_rendered_links_on_tenant_scan_classification ON public.crawl_rendered_links USING btree (organization_id, scan_id, classification, id);


--
-- Name: index_crawl_rendered_page_facts_on_page_render_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_rendered_page_facts_on_page_render_id ON public.crawl_rendered_page_facts USING btree (page_render_id);


--
-- Name: index_crawl_robots_snapshots_on_scan_origin; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_robots_snapshots_on_scan_origin ON public.crawl_robots_snapshots USING btree (scan_id, origin_digest);


--
-- Name: index_crawl_robots_snapshots_on_tenant_scan; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_robots_snapshots_on_tenant_scan ON public.crawl_robots_snapshots USING btree (organization_id, project_id, property_id, scan_id);


--
-- Name: index_crawl_scan_executions_on_recovery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_scan_executions_on_recovery ON public.crawl_scan_executions USING btree (state, initialization_lease_expires_at, id);


--
-- Name: index_crawl_scan_executions_on_scan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_scan_executions_on_scan_id ON public.crawl_scan_executions USING btree (scan_id);


--
-- Name: index_crawl_scan_usage_operations_on_allocation; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_scan_usage_operations_on_allocation ON public.crawl_scan_usage_operations USING btree (usage_quota_allocation_id) WHERE (usage_quota_allocation_id IS NOT NULL);


--
-- Name: index_crawl_scan_usage_operations_on_breakdown; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_scan_usage_operations_on_breakdown ON public.crawl_scan_usage_operations USING btree (organization_id, scan_id, operation_kind, state, attempted_at, id);


--
-- Name: index_crawl_scan_usage_operations_on_event; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_scan_usage_operations_on_event ON public.crawl_scan_usage_operations USING btree (usage_event_id) WHERE (usage_event_id IS NOT NULL);


--
-- Name: index_crawl_scan_usage_operations_on_recovery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_scan_usage_operations_on_recovery ON public.crawl_scan_usage_operations USING btree (state, attempted_at, id) WHERE ((state)::text = 'reserved'::text);


--
-- Name: index_crawl_scan_usage_operations_on_source; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_scan_usage_operations_on_source ON public.crawl_scan_usage_operations USING btree (organization_id, scan_id, source_key_digest);


--
-- Name: index_crawl_sitemap_discoveries_on_scan_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_sitemap_discoveries_on_scan_and_id ON public.crawl_sitemap_discoveries USING btree (scan_id, id);


--
-- Name: index_crawl_sitemap_discoveries_on_scan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_sitemap_discoveries_on_scan_id ON public.crawl_sitemap_discoveries USING btree (scan_id);


--
-- Name: index_crawl_sitemap_discoveries_on_tenant_scan; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_sitemap_discoveries_on_tenant_scan ON public.crawl_sitemap_discoveries USING btree (organization_id, project_id, property_id, scan_id);


--
-- Name: index_crawl_sitemap_entries_on_file_location; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_sitemap_entries_on_file_location ON public.crawl_sitemap_entries USING btree (sitemap_file_id, entry_kind, location_digest);


--
-- Name: index_crawl_sitemap_entries_on_file_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_sitemap_entries_on_file_position ON public.crawl_sitemap_entries USING btree (sitemap_file_id, entry_index);


--
-- Name: index_crawl_sitemap_entries_on_scan_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_sitemap_entries_on_scan_location ON public.crawl_sitemap_entries USING btree (scan_id, entry_kind, location_digest);


--
-- Name: index_crawl_sitemap_entries_on_scan_outcome; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_sitemap_entries_on_scan_outcome ON public.crawl_sitemap_entries USING btree (scan_id, scope_status, relationship_status);


--
-- Name: index_crawl_sitemap_files_on_discovery_queue; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_sitemap_files_on_discovery_queue ON public.crawl_sitemap_files USING btree (sitemap_discovery_id, status, index_depth, created_at);


--
-- Name: index_crawl_sitemap_files_on_scan_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_sitemap_files_on_scan_and_id ON public.crawl_sitemap_files USING btree (scan_id, id);


--
-- Name: index_crawl_sitemap_files_on_scan_url; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_sitemap_files_on_scan_url ON public.crawl_sitemap_files USING btree (scan_id, url_digest);


--
-- Name: index_crawl_urls_on_pending_eligibility; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_urls_on_pending_eligibility ON public.crawl_urls USING btree (next_attempt_at, priority DESC, depth, id) INCLUDE (organization_id, scan_id, host_digest) WHERE ((state)::text = 'pending'::text);


--
-- Name: index_crawl_urls_on_pending_fairness; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_urls_on_pending_fairness ON public.crawl_urls USING btree (organization_id, host_digest, next_attempt_at, priority DESC, depth, id) INCLUDE (scan_id) WHERE ((state)::text = 'pending'::text);


--
-- Name: index_crawl_urls_on_scan_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_urls_on_scan_and_id ON public.crawl_urls USING btree (scan_id, id);


--
-- Name: index_crawl_urls_on_scan_url_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crawl_urls_on_scan_url_identity ON public.crawl_urls USING btree (scan_id, normalized_url_digest);


--
-- Name: index_crawl_urls_on_stale_leases; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_urls_on_stale_leases ON public.crawl_urls USING btree (lease_expires_at, id) INCLUDE (organization_id, scan_id) WHERE ((state)::text = 'leased'::text);


--
-- Name: index_crawl_urls_on_tenant_scan_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crawl_urls_on_tenant_scan_state ON public.crawl_urls USING btree (organization_id, project_id, scan_id, state, id);


--
-- Name: index_deletion_stages_on_workflow_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_deletion_stages_on_workflow_position ON public.resource_deletion_stage_executions USING btree (resource_deletion_workflow_id, "position");


--
-- Name: index_deletion_stages_on_workflow_stage; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_deletion_stages_on_workflow_stage ON public.resource_deletion_stage_executions USING btree (resource_deletion_workflow_id, stage);


--
-- Name: index_deletion_workflows_on_active_target; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_deletion_workflows_on_active_target ON public.resource_deletion_workflows USING btree (organization_id, target_type, target_id) WHERE ((state)::text = ANY (ARRAY[('holding'::character varying)::text, ('running'::character varying)::text, ('retryable'::character varying)::text]));


--
-- Name: index_deletion_workflows_on_due_work; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_deletion_workflows_on_due_work ON public.resource_deletion_workflows USING btree (state, hold_until, next_attempt_at);


--
-- Name: index_deletion_workflows_on_exact_target_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_deletion_workflows_on_exact_target_identity ON public.resource_deletion_workflows USING btree (organization_id, id, target_type, target_id);


--
-- Name: index_deletion_workflows_on_tenant_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_deletion_workflows_on_tenant_identity ON public.resource_deletion_workflows USING btree (organization_id, id);


--
-- Name: index_domain_verifications_on_challenge_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_domain_verifications_on_challenge_digest ON public.domain_verifications USING btree (challenge_digest);


--
-- Name: index_domain_verifications_on_current_environment; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_domain_verifications_on_current_environment ON public.domain_verifications USING btree (organization_id, environment_id) WHERE ((state)::text = ANY (ARRAY[('pending'::character varying)::text, ('verified'::character varying)::text]));


--
-- Name: index_domain_verifications_on_environment_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_domain_verifications_on_environment_state ON public.domain_verifications USING btree (organization_id, project_id, property_id, environment_id, state, created_at);


--
-- Name: index_domain_verifications_on_integration; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_domain_verifications_on_integration ON public.domain_verifications USING btree (organization_id, integration_connection_id);


--
-- Name: index_domain_verifications_on_tenant_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_domain_verifications_on_tenant_identity ON public.domain_verifications USING btree (organization_id, project_id, property_id, environment_id, id);


--
-- Name: index_entitlement_contexts_on_active_organization; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_entitlement_contexts_on_active_organization ON public.entitlement_subscription_contexts USING btree (organization_id) WHERE (active = true);


--
-- Name: index_entitlement_definitions_on_id_and_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_entitlement_definitions_on_id_and_type ON public.entitlement_definitions USING btree (id, value_type);


--
-- Name: index_entitlement_definitions_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_entitlement_definitions_on_key ON public.entitlement_definitions USING btree (key);


--
-- Name: index_entitlement_overrides_on_active_definition; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_entitlement_overrides_on_active_definition ON public.organization_entitlement_overrides USING btree (organization_id, entitlement_definition_id) WHERE (revoked_at IS NULL);


--
-- Name: index_entitlement_overrides_on_validity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entitlement_overrides_on_validity ON public.organization_entitlement_overrides USING btree (organization_id, starts_at, ends_at);


--
-- Name: index_entitlement_subscription_contexts_on_subscription_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_entitlement_subscription_contexts_on_subscription_id ON public.entitlement_subscription_contexts USING btree (subscription_id);


--
-- Name: index_identities_on_active_user_and_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_identities_on_active_user_and_provider ON public.identities USING btree (user_id, provider) WHERE (revoked_at IS NULL);


--
-- Name: index_identities_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_identities_on_email ON public.identities USING btree (email);


--
-- Name: index_identities_on_provider_and_provider_subject; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_identities_on_provider_and_provider_subject ON public.identities USING btree (provider, provider_subject);


--
-- Name: index_identities_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_identities_on_user_id ON public.identities USING btree (user_id);


--
-- Name: index_identities_on_user_id_and_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_identities_on_user_id_and_provider ON public.identities USING btree (user_id, provider);


--
-- Name: index_integration_connections_on_active_account; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_integration_connections_on_active_account ON public.integration_connections USING btree (organization_id, provider, external_account_id) WHERE ((state)::text <> 'revoked'::text);


--
-- Name: index_integration_connections_on_consent_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_integration_connections_on_consent_digest ON public.integration_connections USING btree (consent_digest);


--
-- Name: index_integration_connections_on_tenant_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_integration_connections_on_tenant_identity ON public.integration_connections USING btree (organization_id, id);


--
-- Name: index_invitation_rate_limit_buckets_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invitation_rate_limit_buckets_on_expires_at ON public.invitation_rate_limit_buckets USING btree (expires_at);


--
-- Name: index_invitation_rate_limits_on_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_invitation_rate_limits_on_identity ON public.invitation_rate_limit_buckets USING btree (scope, key_digest, window_started_at);


--
-- Name: index_invitations_on_email_status_and_expiry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invitations_on_email_status_and_expiry ON public.invitations USING btree (email, status, expires_at);


--
-- Name: index_invitations_on_org_status_and_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invitations_on_org_status_and_created ON public.invitations USING btree (organization_id, status, created_at);


--
-- Name: index_invitations_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invitations_on_organization_id ON public.invitations USING btree (organization_id);


--
-- Name: index_invitations_on_pending_org_and_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_invitations_on_pending_org_and_email ON public.invitations USING btree (organization_id, email) WHERE ((status)::text = 'pending'::text);


--
-- Name: index_invitations_on_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_invitations_on_token_digest ON public.invitations USING btree (token_digest);


--
-- Name: index_ios_configs_on_normalized_application; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ios_configs_on_normalized_application ON public.ios_property_configs USING btree (organization_id, project_id, team_id, bundle_id);


--
-- Name: index_memberships_on_org_id_status; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_memberships_on_org_id_status ON public.memberships USING btree (organization_id, id, status);


--
-- Name: index_memberships_on_org_status_and_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_memberships_on_org_status_and_created ON public.memberships USING btree (organization_id, status, created_at);


--
-- Name: index_memberships_on_organization_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_memberships_on_organization_and_id ON public.memberships USING btree (organization_id, id);


--
-- Name: index_memberships_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_memberships_on_organization_id ON public.memberships USING btree (organization_id);


--
-- Name: index_memberships_on_organization_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_memberships_on_organization_id_and_user_id ON public.memberships USING btree (organization_id, user_id);


--
-- Name: index_memberships_on_user_status_and_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_memberships_on_user_status_and_org ON public.memberships USING btree (user_id, status, organization_id);


--
-- Name: index_oauth_transactions_on_initiator_and_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_oauth_transactions_on_initiator_and_created ON public.oauth_transactions USING btree (initiator_digest, created_at);


--
-- Name: index_oauth_transactions_on_link_session; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_oauth_transactions_on_link_session ON public.oauth_transactions USING btree (link_session_id, created_at) WHERE link_intent;


--
-- Name: index_oauth_transactions_on_nonce_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_oauth_transactions_on_nonce_digest ON public.oauth_transactions USING btree (nonce_digest) WHERE (nonce_digest IS NOT NULL);


--
-- Name: index_oauth_transactions_on_open_expiry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_oauth_transactions_on_open_expiry ON public.oauth_transactions USING btree (expires_at) WHERE (consumed_at IS NULL);


--
-- Name: index_oauth_transactions_on_open_initiator; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_oauth_transactions_on_open_initiator ON public.oauth_transactions USING btree (initiator_digest, expires_at) WHERE (consumed_at IS NULL);


--
-- Name: index_oauth_transactions_on_pkce_verifier_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_oauth_transactions_on_pkce_verifier_digest ON public.oauth_transactions USING btree (pkce_verifier_digest);


--
-- Name: index_oauth_transactions_on_state_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_oauth_transactions_on_state_digest ON public.oauth_transactions USING btree (state_digest);


--
-- Name: index_organization_ownerships_on_active_membership; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_organization_ownerships_on_active_membership ON public.organization_ownerships USING btree (membership_id) WHERE (ended_at IS NULL);


--
-- Name: index_organization_ownerships_on_active_org; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_organization_ownerships_on_active_org ON public.organization_ownerships USING btree (organization_id) WHERE (ended_at IS NULL);


--
-- Name: index_organization_ownerships_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_organization_ownerships_on_organization_id ON public.organization_ownerships USING btree (organization_id);


--
-- Name: index_organization_slug_aliases_on_org_and_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_organization_slug_aliases_on_org_and_created ON public.organization_slug_aliases USING btree (organization_id, created_at);


--
-- Name: index_organization_slug_aliases_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_organization_slug_aliases_on_organization_id ON public.organization_slug_aliases USING btree (organization_id);


--
-- Name: index_organization_slug_aliases_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_organization_slug_aliases_on_slug ON public.organization_slug_aliases USING btree (slug);


--
-- Name: index_organizations_on_active_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_organizations_on_active_slug ON public.organizations USING btree (slug) WHERE (deleted_at IS NULL);


--
-- Name: index_outbox_events_on_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_outbox_events_on_idempotency_key ON public.outbox_events USING btree (idempotency_key);


--
-- Name: index_outbox_events_on_published_at_and_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_outbox_events_on_published_at_and_occurred_at ON public.outbox_events USING btree (published_at, occurred_at);


--
-- Name: index_ownerships_on_org_id_current; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ownerships_on_org_id_current ON public.organization_ownerships USING btree (organization_id, id, current);


--
-- Name: index_permissions_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_permissions_on_key ON public.permissions USING btree (key);


--
-- Name: index_plan_catalog_grants_on_active_permission; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_plan_catalog_grants_on_active_permission ON public.plan_catalog_access_grants USING btree (user_id, permission) WHERE (revoked_at IS NULL);


--
-- Name: index_plan_entitlements_on_version_and_definition; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_plan_entitlements_on_version_and_definition ON public.plan_entitlements USING btree (plan_version_id, entitlement_definition_id);


--
-- Name: index_plan_version_snapshot_references_on_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_plan_version_snapshot_references_on_identity ON public.plan_version_snapshot_references USING btree (reference_type, reference_id, plan_version_id);


--
-- Name: index_plan_versions_on_catalog_checksum; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_plan_versions_on_catalog_checksum ON public.plan_versions USING btree (catalog_checksum);


--
-- Name: index_plan_versions_on_catalog_selection; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_plan_versions_on_catalog_selection ON public.plan_versions USING btree (plan_id, status, effective_at);


--
-- Name: index_plan_versions_on_plan_id_and_version; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_plan_versions_on_plan_id_and_version ON public.plan_versions USING btree (plan_id, version);


--
-- Name: index_plans_on_display_order; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_plans_on_display_order ON public.plans USING btree (display_order);


--
-- Name: index_plans_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_plans_on_key ON public.plans USING btree (key);


--
-- Name: index_project_onboarding_drafts_on_active_actor; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_project_onboarding_drafts_on_active_actor ON public.project_onboarding_drafts USING btree (organization_id, actor_membership_id) WHERE ((state)::text = 'draft'::text);


--
-- Name: index_project_onboarding_drafts_on_android_property_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_project_onboarding_drafts_on_android_property_id ON public.project_onboarding_drafts USING btree (android_property_id);


--
-- Name: index_project_onboarding_drafts_on_ios_property_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_project_onboarding_drafts_on_ios_property_id ON public.project_onboarding_drafts USING btree (ios_property_id);


--
-- Name: index_project_onboarding_drafts_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_project_onboarding_drafts_on_project_id ON public.project_onboarding_drafts USING btree (project_id);


--
-- Name: index_project_onboarding_drafts_on_project_release_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_project_onboarding_drafts_on_project_release_key ON public.project_onboarding_drafts USING btree (project_release_key);


--
-- Name: index_project_onboarding_drafts_on_stale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_onboarding_drafts_on_stale ON public.project_onboarding_drafts USING btree (organization_id, updated_at) WHERE ((state)::text = 'draft'::text);


--
-- Name: index_project_onboarding_drafts_on_website_property_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_project_onboarding_drafts_on_website_property_id ON public.project_onboarding_drafts USING btree (website_property_id);


--
-- Name: index_projects_on_deletion_workflow_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_deletion_workflow_id ON public.projects USING btree (deletion_workflow_id) WHERE (deletion_workflow_id IS NOT NULL);


--
-- Name: index_projects_on_external_release_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_external_release_key ON public.projects USING btree (external_release_key);


--
-- Name: index_projects_on_org_status_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_org_status_name ON public.projects USING btree (organization_id, status, name, id);


--
-- Name: index_projects_on_organization_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_organization_and_id ON public.projects USING btree (organization_id, id);


--
-- Name: index_projects_on_organization_and_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_organization_and_slug ON public.projects USING btree (organization_id, slug);


--
-- Name: index_properties_on_deletion_workflow_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_properties_on_deletion_workflow_id ON public.properties USING btree (deletion_workflow_id) WHERE (deletion_workflow_id IS NOT NULL);


--
-- Name: index_properties_on_exact_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_properties_on_exact_identity ON public.properties USING btree (organization_id, project_id, id);


--
-- Name: index_properties_on_project_and_display_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_properties_on_project_and_display_name ON public.properties USING btree (organization_id, project_id, display_name);


--
-- Name: index_properties_on_project_status_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_properties_on_project_status_name ON public.properties USING btree (organization_id, project_id, status, display_name, id);


--
-- Name: index_properties_on_typed_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_properties_on_typed_identity ON public.properties USING btree (organization_id, project_id, id, kind, configuration_version);


--
-- Name: index_property_environments_on_directory; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_property_environments_on_directory ON public.property_environments USING btree (organization_id, project_id, property_id, status, kind, display_name, id);


--
-- Name: index_property_environments_on_origin; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_property_environments_on_origin ON public.property_environments USING btree (organization_id, project_id, origin);


--
-- Name: index_property_environments_on_primary_production; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_property_environments_on_primary_production ON public.property_environments USING btree (organization_id, project_id, property_id) WHERE (("primary" = true) AND ((status)::text = 'active'::text) AND ((kind)::text = 'production'::text));


--
-- Name: index_property_environments_on_stable_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_property_environments_on_stable_key ON public.property_environments USING btree (organization_id, project_id, property_id, key);


--
-- Name: index_property_environments_on_tenant_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_property_environments_on_tenant_identity ON public.property_environments USING btree (organization_id, project_id, property_id, id);


--
-- Name: index_role_assignments_on_active_grant; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_role_assignments_on_active_grant ON public.role_assignments USING btree (organization_id, grantee_type, grantee_id, role_id, scope_type, scope_id) WHERE (revoked_at IS NULL);


--
-- Name: index_role_assignments_on_effective_principal; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_role_assignments_on_effective_principal ON public.role_assignments USING btree (organization_id, grantee_type, grantee_id, revoked_at, expires_at);


--
-- Name: index_role_assignments_on_effective_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_role_assignments_on_effective_scope ON public.role_assignments USING btree (organization_id, scope_type, scope_id, revoked_at, expires_at);


--
-- Name: index_role_assignments_on_role_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_role_assignments_on_role_id ON public.role_assignments USING btree (role_id);


--
-- Name: index_role_permissions_on_permission_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_role_permissions_on_permission_id ON public.role_permissions USING btree (permission_id);


--
-- Name: index_role_permissions_on_role_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_role_permissions_on_role_id ON public.role_permissions USING btree (role_id);


--
-- Name: index_role_permissions_on_role_id_and_permission_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_role_permissions_on_role_id_and_permission_id ON public.role_permissions USING btree (role_id, permission_id);


--
-- Name: index_roles_on_id_and_system; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_roles_on_id_and_system ON public.roles USING btree (id, system);


--
-- Name: index_roles_on_organization_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_roles_on_organization_and_id ON public.roles USING btree (organization_id, id);


--
-- Name: index_roles_on_organization_and_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_roles_on_organization_and_key ON public.roles USING btree (organization_id, key) WHERE (system = false);


--
-- Name: index_roles_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_roles_on_organization_id ON public.roles USING btree (organization_id);


--
-- Name: index_roles_on_system_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_roles_on_system_key ON public.roles USING btree (key) WHERE (system = true);


--
-- Name: index_scan_events_on_idempotency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_scan_events_on_idempotency ON public.scan_events USING btree (scan_id, idempotency_key_digest);


--
-- Name: index_scan_events_on_project_timeline; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scan_events_on_project_timeline ON public.scan_events USING btree (organization_id, project_id, scan_id, occurred_at);


--
-- Name: index_scan_events_on_sequence; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_scan_events_on_sequence ON public.scan_events USING btree (scan_id, sequence);


--
-- Name: index_scans_on_active_global_work; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scans_on_active_global_work ON public.scans USING btree (status) WHERE ((status)::text = ANY (ARRAY[('admitted'::character varying)::text, ('queued'::character varying)::text, ('running'::character varying)::text, ('cancel_requested'::character varying)::text]));


--
-- Name: index_scans_on_active_organization_work; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scans_on_active_organization_work ON public.scans USING btree (organization_id, status) WHERE ((status)::text = ANY (ARRAY[('admitted'::character varying)::text, ('queued'::character varying)::text, ('running'::character varying)::text, ('cancel_requested'::character varying)::text]));


--
-- Name: index_scans_on_active_project_admissions; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scans_on_active_project_admissions ON public.scans USING btree (organization_id, project_id, status) WHERE ((status)::text = ANY (ARRAY[('admitted'::character varying)::text, ('queued'::character varying)::text, ('running'::character varying)::text, ('cancel_requested'::character varying)::text]));


--
-- Name: index_scans_on_active_project_work; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scans_on_active_project_work ON public.scans USING btree (organization_id, project_id, status, updated_at) WHERE ((status)::text = ANY (ARRAY[('requested'::character varying)::text, ('admitted'::character varying)::text, ('queued'::character varying)::text, ('running'::character varying)::text, ('cancel_requested'::character varying)::text]));


--
-- Name: index_scans_on_baseline_scan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scans_on_baseline_scan_id ON public.scans USING btree (baseline_scan_id) WHERE (baseline_scan_id IS NOT NULL);


--
-- Name: index_scans_on_exact_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_scans_on_exact_identity ON public.scans USING btree (organization_id, project_id, property_id, environment_id, id);


--
-- Name: index_scans_on_pending_dispatch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scans_on_pending_dispatch ON public.scans USING btree (status, dispatch_enqueued_at, admitted_at) WHERE (((status)::text = 'admitted'::text) AND (dispatch_enqueued_at IS NULL));


--
-- Name: index_scans_on_project_timeline; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scans_on_project_timeline ON public.scans USING btree (organization_id, project_id, requested_at DESC, id DESC);


--
-- Name: index_scans_on_release_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scans_on_release_id ON public.scans USING btree (release_id) WHERE (release_id IS NOT NULL);


--
-- Name: index_scans_on_tenant_admission_idempotency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_scans_on_tenant_admission_idempotency ON public.scans USING btree (organization_id, request_idempotency_digest) WHERE (request_idempotency_digest IS NOT NULL);


--
-- Name: index_scans_on_throttle_observation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scans_on_throttle_observation ON public.scans USING btree (throttled_at, id) WHERE (throttled_at IS NOT NULL);


--
-- Name: index_sessions_on_active_expiry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_active_expiry ON public.sessions USING btree (expires_at) WHERE (revoked_at IS NULL);


--
-- Name: index_sessions_on_revoked_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_revoked_at ON public.sessions USING btree (revoked_at) WHERE (revoked_at IS NOT NULL);


--
-- Name: index_sessions_on_rotated_from_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_rotated_from_id ON public.sessions USING btree (rotated_from_id);


--
-- Name: index_sessions_on_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sessions_on_token_digest ON public.sessions USING btree (token_digest);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


--
-- Name: index_sessions_on_user_id_and_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id_and_expires_at ON public.sessions USING btree (user_id, expires_at);


--
-- Name: index_subscriptions_on_current_organization; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_subscriptions_on_current_organization ON public.subscriptions USING btree (organization_id) WHERE (ended_at IS NULL);


--
-- Name: index_subscriptions_on_org_id_plan_version; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_subscriptions_on_org_id_plan_version ON public.subscriptions USING btree (organization_id, id, plan_version_id);


--
-- Name: index_subscriptions_on_plan_version_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_plan_version_id_and_status ON public.subscriptions USING btree (plan_version_id, status);


--
-- Name: index_subscriptions_on_provider_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_subscriptions_on_provider_identity ON public.subscriptions USING btree (provider, provider_environment, provider_subscription_id) WHERE (provider_subscription_id IS NOT NULL);


--
-- Name: index_subscriptions_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_subscriptions_on_tenant_id ON public.subscriptions USING btree (organization_id, id);


--
-- Name: index_subscriptions_on_tenant_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_subscriptions_on_tenant_identity ON public.subscriptions USING btree (organization_id, id);


--
-- Name: index_team_memberships_on_active_team_and_member; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_team_memberships_on_active_team_and_member ON public.team_memberships USING btree (team_id, membership_id) WHERE (removed_at IS NULL);


--
-- Name: index_team_memberships_on_org_member_and_removed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_team_memberships_on_org_member_and_removed ON public.team_memberships USING btree (organization_id, membership_id, removed_at);


--
-- Name: index_team_memberships_on_org_team_and_added; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_team_memberships_on_org_team_and_added ON public.team_memberships USING btree (organization_id, team_id, added_at);


--
-- Name: index_teams_on_active_organization_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_teams_on_active_organization_and_name ON public.teams USING btree (organization_id, name) WHERE (archived_at IS NULL);


--
-- Name: index_teams_on_org_status_and_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_teams_on_org_status_and_created ON public.teams USING btree (organization_id, status, created_at);


--
-- Name: index_teams_on_organization_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_teams_on_organization_and_id ON public.teams USING btree (organization_id, id);


--
-- Name: index_teams_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_teams_on_organization_id ON public.teams USING btree (organization_id);


--
-- Name: index_usage_events_on_correction_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_usage_events_on_correction_identity ON public.usage_events USING btree (organization_id, id, usage_window_id, usage_meter_definition_id);


--
-- Name: index_usage_events_on_meter_occurred; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_events_on_meter_occurred ON public.usage_events USING btree (usage_meter_definition_id, occurred_at);


--
-- Name: index_usage_events_on_tenant_idempotency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_usage_events_on_tenant_idempotency ON public.usage_events USING btree (organization_id, idempotency_key_digest);


--
-- Name: index_usage_events_on_tenant_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_usage_events_on_tenant_identity ON public.usage_events USING btree (organization_id, id);


--
-- Name: index_usage_events_on_tenant_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_events_on_tenant_source ON public.usage_events USING btree (organization_id, source_type, source_id, occurred_at);


--
-- Name: index_usage_events_on_tenant_window_recorded; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_events_on_tenant_window_recorded ON public.usage_events USING btree (organization_id, usage_window_id, recorded_at, id);


--
-- Name: index_usage_meter_definitions_on_id_and_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_usage_meter_definitions_on_id_and_key ON public.usage_meter_definitions USING btree (id, key);


--
-- Name: index_usage_meter_definitions_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_usage_meter_definitions_on_key ON public.usage_meter_definitions USING btree (key);


--
-- Name: index_usage_meter_rates_on_definition_and_effective_at; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_usage_meter_rates_on_definition_and_effective_at ON public.usage_meter_rates USING btree (usage_meter_definition_id, effective_at);


--
-- Name: index_usage_meter_rates_on_definition_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_usage_meter_rates_on_definition_and_id ON public.usage_meter_rates USING btree (usage_meter_definition_id, id);


--
-- Name: index_usage_meter_rates_on_definition_and_version; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_usage_meter_rates_on_definition_and_version ON public.usage_meter_rates USING btree (usage_meter_definition_id, version);


--
-- Name: index_usage_quota_allocations_on_event; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_usage_quota_allocations_on_event ON public.usage_quota_allocations USING btree (usage_event_id) WHERE (usage_event_id IS NOT NULL);


--
-- Name: index_usage_quota_allocations_on_reservation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_quota_allocations_on_reservation ON public.usage_quota_allocations USING btree (organization_id, usage_quota_reservation_id, state, allocated_at, id);


--
-- Name: index_usage_quota_allocations_on_tenant_idempotency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_usage_quota_allocations_on_tenant_idempotency ON public.usage_quota_allocations USING btree (organization_id, idempotency_key_digest);


--
-- Name: index_usage_quota_allocations_on_tenant_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_usage_quota_allocations_on_tenant_identity ON public.usage_quota_allocations USING btree (organization_id, id);


--
-- Name: index_usage_quota_operations_on_event; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_usage_quota_operations_on_event ON public.usage_quota_reservation_operations USING btree (usage_event_id) WHERE (usage_event_id IS NOT NULL);


--
-- Name: index_usage_quota_operations_on_reservation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_quota_operations_on_reservation ON public.usage_quota_reservation_operations USING btree (organization_id, usage_quota_reservation_id, created_at, id);


--
-- Name: index_usage_quota_operations_on_tenant_idempotency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_usage_quota_operations_on_tenant_idempotency ON public.usage_quota_reservation_operations USING btree (organization_id, idempotency_key_digest);


--
-- Name: index_usage_quota_reservations_on_active_pool; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_quota_reservations_on_active_pool ON public.usage_quota_reservations USING btree (organization_id, usage_window_id, state, expires_at);


--
-- Name: index_usage_quota_reservations_on_finalized_event; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_usage_quota_reservations_on_finalized_event ON public.usage_quota_reservations USING btree (finalized_usage_event_id) WHERE (finalized_usage_event_id IS NOT NULL);


--
-- Name: index_usage_quota_reservations_on_stale_holds; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_quota_reservations_on_stale_holds ON public.usage_quota_reservations USING btree (state, expires_at) WHERE ((state)::text = 'held'::text);


--
-- Name: index_usage_quota_reservations_on_tenant_idempotency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_usage_quota_reservations_on_tenant_idempotency ON public.usage_quota_reservations USING btree (organization_id, idempotency_key_digest);


--
-- Name: index_usage_quota_reservations_on_tenant_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_usage_quota_reservations_on_tenant_identity ON public.usage_quota_reservations USING btree (organization_id, id);


--
-- Name: index_usage_quota_reservations_on_tenant_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_quota_reservations_on_tenant_source ON public.usage_quota_reservations USING btree (organization_id, source_type, source_id, created_at);


--
-- Name: index_usage_windows_on_provider_period; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_usage_windows_on_provider_period ON public.usage_windows USING btree (organization_id, usage_meter_definition_id, period_reference_digest) WHERE (period_reference_digest IS NOT NULL);


--
-- Name: index_usage_windows_on_subscription_period; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_windows_on_subscription_period ON public.usage_windows USING btree (subscription_id, starts_at);


--
-- Name: index_usage_windows_on_tenant_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_usage_windows_on_tenant_identity ON public.usage_windows USING btree (organization_id, id, usage_meter_definition_id);


--
-- Name: index_usage_windows_on_tenant_meter_period; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_usage_windows_on_tenant_meter_period ON public.usage_windows USING btree (organization_id, usage_meter_definition_id, starts_at, ends_at);


--
-- Name: index_usage_windows_on_tenant_period; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_windows_on_tenant_period ON public.usage_windows USING btree (organization_id, starts_at, ends_at);


--
-- Name: index_users_on_active_normalized_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_active_normalized_email ON public.users USING btree (lower((primary_email)::text)) WHERE ((primary_email IS NOT NULL) AND (deleted_at IS NULL));


--
-- Name: index_verification_attempts_on_environment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_verification_attempts_on_environment ON public.domain_verification_attempts USING btree (organization_id, project_id, property_id, environment_id, attempted_at);


--
-- Name: index_verification_attempts_on_sequence; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_verification_attempts_on_sequence ON public.domain_verification_attempts USING btree (domain_verification_id, sequence);


--
-- Name: index_website_configs_on_normalized_origin; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_website_configs_on_normalized_origin ON public.website_property_configs USING btree (organization_id, project_id, origin);


--
-- Name: audit_target_tombstones audit_target_tombstones_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_target_tombstones_immutable BEFORE DELETE OR UPDATE ON public.audit_target_tombstones FOR EACH ROW EXECUTE FUNCTION public.prevent_audit_target_tombstone_mutation();


--
-- Name: billing_customers billing_customers_immutable_mapping; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER billing_customers_immutable_mapping BEFORE DELETE OR UPDATE ON public.billing_customers FOR EACH ROW EXECUTE FUNCTION public.enforce_billing_customer_mapping_immutability();


--
-- Name: crawl_fetch_permits crawl_fetch_permits_protect_provenance; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER crawl_fetch_permits_protect_provenance BEFORE DELETE OR UPDATE ON public.crawl_fetch_permits FOR EACH ROW EXECUTE FUNCTION public.protect_crawl_fetch_permit_provenance();


--
-- Name: crawl_fetch_results crawl_fetch_results_protect_rows; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER crawl_fetch_results_protect_rows BEFORE DELETE OR UPDATE ON public.crawl_fetch_results FOR EACH ROW EXECUTE FUNCTION public.protect_crawl_fetch_result_rows();


--
-- Name: crawl_links crawl_links_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER crawl_links_immutable BEFORE DELETE OR UPDATE ON public.crawl_links FOR EACH ROW EXECUTE FUNCTION public.protect_crawl_link_rows();


--
-- Name: crawl_page_facts crawl_page_facts_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER crawl_page_facts_immutable BEFORE DELETE OR UPDATE ON public.crawl_page_facts FOR EACH ROW EXECUTE FUNCTION public.protect_crawl_page_fact_rows();


--
-- Name: crawl_page_renders crawl_page_renders_protect_rows; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER crawl_page_renders_protect_rows BEFORE DELETE OR UPDATE ON public.crawl_page_renders FOR EACH ROW EXECUTE FUNCTION public.protect_crawl_page_render_rows();


--
-- Name: crawl_page_snapshots crawl_page_snapshots_protect_identity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER crawl_page_snapshots_protect_identity BEFORE DELETE OR UPDATE ON public.crawl_page_snapshots FOR EACH ROW EXECUTE FUNCTION public.protect_crawl_page_snapshot_identity();


--
-- Name: crawl_policy_sets crawl_policy_sets_require_deletion_workflow; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER crawl_policy_sets_require_deletion_workflow BEFORE DELETE ON public.crawl_policy_sets FOR EACH ROW EXECUTE FUNCTION public.protect_crawl_policy_set_deletion();


--
-- Name: crawl_policy_snapshots crawl_policy_snapshots_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER crawl_policy_snapshots_immutable BEFORE DELETE OR UPDATE ON public.crawl_policy_snapshots FOR EACH ROW EXECUTE FUNCTION public.reject_crawl_policy_immutable_change();


--
-- Name: crawl_policy_versions crawl_policy_versions_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER crawl_policy_versions_immutable BEFORE DELETE OR UPDATE ON public.crawl_policy_versions FOR EACH ROW EXECUTE FUNCTION public.reject_crawl_policy_immutable_change();


--
-- Name: crawl_rendered_links crawl_rendered_links_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER crawl_rendered_links_immutable BEFORE DELETE OR UPDATE ON public.crawl_rendered_links FOR EACH ROW EXECUTE FUNCTION public.protect_crawl_rendered_link_rows();


--
-- Name: crawl_rendered_page_facts crawl_rendered_page_facts_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER crawl_rendered_page_facts_immutable BEFORE DELETE OR UPDATE ON public.crawl_rendered_page_facts FOR EACH ROW EXECUTE FUNCTION public.protect_crawl_rendered_page_fact_rows();


--
-- Name: crawl_robots_snapshots crawl_robots_snapshots_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER crawl_robots_snapshots_immutable BEFORE DELETE OR UPDATE ON public.crawl_robots_snapshots FOR EACH ROW EXECUTE FUNCTION public.protect_crawl_robots_snapshot();


--
-- Name: crawl_scan_executions crawl_scan_executions_protect_identity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER crawl_scan_executions_protect_identity BEFORE DELETE OR UPDATE ON public.crawl_scan_executions FOR EACH ROW EXECUTE FUNCTION public.protect_crawl_scan_execution_identity();


--
-- Name: crawl_scan_usage_operations crawl_scan_usage_operations_lifecycle; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER crawl_scan_usage_operations_lifecycle BEFORE INSERT OR DELETE OR UPDATE ON public.crawl_scan_usage_operations FOR EACH ROW EXECUTE FUNCTION public.enforce_crawl_scan_usage_operation_lifecycle();


--
-- Name: crawl_sitemap_discoveries crawl_sitemap_discoveries_protect; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER crawl_sitemap_discoveries_protect BEFORE DELETE OR UPDATE ON public.crawl_sitemap_discoveries FOR EACH ROW EXECUTE FUNCTION public.protect_crawl_sitemap_discovery();


--
-- Name: crawl_sitemap_entries crawl_sitemap_entries_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER crawl_sitemap_entries_immutable BEFORE DELETE OR UPDATE ON public.crawl_sitemap_entries FOR EACH ROW EXECUTE FUNCTION public.protect_crawl_sitemap_entry();


--
-- Name: crawl_sitemap_files crawl_sitemap_files_protect; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER crawl_sitemap_files_protect BEFORE DELETE OR UPDATE ON public.crawl_sitemap_files FOR EACH ROW EXECUTE FUNCTION public.protect_crawl_sitemap_file();


--
-- Name: crawl_urls crawl_urls_protect_identity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER crawl_urls_protect_identity BEFORE DELETE OR UPDATE ON public.crawl_urls FOR EACH ROW EXECUTE FUNCTION public.protect_crawl_url_identity();


--
-- Name: domain_verification_attempts domain_verification_attempts_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER domain_verification_attempts_immutable BEFORE DELETE OR UPDATE ON public.domain_verification_attempts FOR EACH ROW EXECUTE FUNCTION public.prevent_domain_verification_attempt_mutation();


--
-- Name: domain_verifications domain_verifications_protect_binding; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER domain_verifications_protect_binding BEFORE UPDATE ON public.domain_verifications FOR EACH ROW EXECUTE FUNCTION public.protect_domain_verification_binding();


--
-- Name: domain_verifications domain_verifications_require_deletion_workflow; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER domain_verifications_require_deletion_workflow BEFORE DELETE ON public.domain_verifications FOR EACH ROW EXECUTE FUNCTION public.protect_domain_verification_deletion();


--
-- Name: domain_verifications domain_verifications_validate_origin; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER domain_verifications_validate_origin BEFORE INSERT ON public.domain_verifications FOR EACH ROW EXECUTE FUNCTION public.validate_domain_verification_origin();


--
-- Name: entitlement_definitions entitlement_definitions_stable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER entitlement_definitions_stable BEFORE DELETE OR UPDATE ON public.entitlement_definitions FOR EACH ROW EXECUTE FUNCTION public.enforce_entitlement_definition_stability();


--
-- Name: integration_connections integration_connections_invalidate_verifications; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER integration_connections_invalidate_verifications AFTER UPDATE OF external_account_id, granted_scopes, credential_revision, state ON public.integration_connections FOR EACH ROW EXECUTE FUNCTION public.invalidate_connection_bound_verifications();


--
-- Name: organization_entitlement_overrides organization_entitlement_overrides_append_only; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER organization_entitlement_overrides_append_only BEFORE DELETE OR UPDATE ON public.organization_entitlement_overrides FOR EACH ROW EXECUTE FUNCTION public.enforce_organization_entitlement_override_append_only();


--
-- Name: plan_entitlements plan_entitlements_immutable_snapshot; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER plan_entitlements_immutable_snapshot BEFORE DELETE OR UPDATE ON public.plan_entitlements FOR EACH ROW EXECUTE FUNCTION public.enforce_plan_entitlement_immutability();


--
-- Name: plan_versions plan_versions_immutable_snapshot; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER plan_versions_immutable_snapshot BEFORE DELETE OR UPDATE ON public.plan_versions FOR EACH ROW EXECUTE FUNCTION public.enforce_plan_version_immutability();


--
-- Name: plans plans_prevent_deletion; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER plans_prevent_deletion BEFORE DELETE ON public.plans FOR EACH ROW EXECUTE FUNCTION public.prevent_plan_deletion();


--
-- Name: projects projects_protect_stable_identity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER projects_protect_stable_identity BEFORE UPDATE ON public.projects FOR EACH ROW EXECUTE FUNCTION public.protect_project_stable_identity();


--
-- Name: projects projects_require_deletion_workflow; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER projects_require_deletion_workflow BEFORE DELETE ON public.projects FOR EACH ROW EXECUTE FUNCTION public.protect_project_lifecycle_deletion();


--
-- Name: properties properties_protect_stable_identity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER properties_protect_stable_identity BEFORE UPDATE ON public.properties FOR EACH ROW EXECUTE FUNCTION public.protect_property_stable_identity();


--
-- Name: properties properties_require_deletion_workflow; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER properties_require_deletion_workflow BEFORE DELETE ON public.properties FOR EACH ROW EXECUTE FUNCTION public.protect_property_lifecycle_deletion();


--
-- Name: properties properties_require_primary_environment; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER properties_require_primary_environment AFTER INSERT OR UPDATE ON public.properties DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.enforce_property_primary_environment();


--
-- Name: property_environments property_environments_invalidate_verifications; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER property_environments_invalidate_verifications AFTER UPDATE OF origin ON public.property_environments FOR EACH ROW EXECUTE FUNCTION public.invalidate_origin_bound_verifications();


--
-- Name: property_environments property_environments_protect_stable_identity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER property_environments_protect_stable_identity BEFORE UPDATE ON public.property_environments FOR EACH ROW EXECUTE FUNCTION public.protect_property_environment_stable_identity();


--
-- Name: property_environments property_environments_require_primary; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER property_environments_require_primary AFTER INSERT OR DELETE OR UPDATE ON public.property_environments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.enforce_property_primary_environment();


--
-- Name: scan_events scan_events_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER scan_events_immutable BEFORE DELETE OR UPDATE ON public.scan_events FOR EACH ROW EXECUTE FUNCTION public.protect_scan_event_history();


--
-- Name: scans scans_protect_inputs; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER scans_protect_inputs BEFORE DELETE OR UPDATE ON public.scans FOR EACH ROW EXECUTE FUNCTION public.protect_scan_inputs();


--
-- Name: usage_events usage_events_immutable_and_consistent; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER usage_events_immutable_and_consistent BEFORE INSERT OR DELETE OR UPDATE ON public.usage_events FOR EACH ROW EXECUTE FUNCTION public.enforce_usage_event_integrity();


--
-- Name: usage_meter_definitions usage_meter_definitions_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER usage_meter_definitions_immutable BEFORE DELETE OR UPDATE ON public.usage_meter_definitions FOR EACH ROW EXECUTE FUNCTION public.enforce_usage_catalog_immutability();


--
-- Name: usage_meter_rates usage_meter_rates_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER usage_meter_rates_immutable BEFORE DELETE OR UPDATE ON public.usage_meter_rates FOR EACH ROW EXECUTE FUNCTION public.enforce_usage_catalog_immutability();


--
-- Name: usage_quota_allocations usage_quota_allocations_lifecycle; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER usage_quota_allocations_lifecycle BEFORE INSERT OR DELETE OR UPDATE ON public.usage_quota_allocations FOR EACH ROW EXECUTE FUNCTION public.enforce_usage_quota_allocation_lifecycle();


--
-- Name: usage_quota_reservation_operations usage_quota_reservation_operations_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER usage_quota_reservation_operations_immutable BEFORE DELETE OR UPDATE ON public.usage_quota_reservation_operations FOR EACH ROW EXECUTE FUNCTION public.enforce_usage_quota_reservation_operation_immutability();


--
-- Name: usage_quota_reservations usage_quota_reservations_lifecycle; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER usage_quota_reservations_lifecycle BEFORE INSERT OR DELETE OR UPDATE ON public.usage_quota_reservations FOR EACH ROW EXECUTE FUNCTION public.enforce_usage_quota_reservation_lifecycle();


--
-- Name: usage_windows usage_windows_non_overlapping; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER usage_windows_non_overlapping BEFORE INSERT OR DELETE OR UPDATE ON public.usage_windows FOR EACH ROW EXECUTE FUNCTION public.enforce_usage_window_integrity();


--
-- Name: android_property_configs fk_android_property_configs_typed_property; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.android_property_configs
    ADD CONSTRAINT fk_android_property_configs_typed_property FOREIGN KEY (organization_id, project_id, property_id, property_kind, configuration_version) REFERENCES public.properties(organization_id, project_id, id, kind, configuration_version) ON DELETE RESTRICT;


--
-- Name: artifact_blobs fk_artifact_blobs_exact_project; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artifact_blobs
    ADD CONSTRAINT fk_artifact_blobs_exact_project FOREIGN KEY (organization_id, project_id) REFERENCES public.projects(organization_id, id) ON DELETE RESTRICT;


--
-- Name: artifact_blobs fk_artifact_blobs_exact_property; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artifact_blobs
    ADD CONSTRAINT fk_artifact_blobs_exact_property FOREIGN KEY (organization_id, project_id, property_id) REFERENCES public.properties(organization_id, project_id, id) ON DELETE RESTRICT;


--
-- Name: artifacts fk_artifacts_exact_blob; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artifacts
    ADD CONSTRAINT fk_artifacts_exact_blob FOREIGN KEY (organization_id, project_id, property_id, artifact_blob_id) REFERENCES public.artifact_blobs(organization_id, project_id, property_id, id) ON DELETE RESTRICT;


--
-- Name: artifacts fk_artifacts_exact_scan; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artifacts
    ADD CONSTRAINT fk_artifacts_exact_scan FOREIGN KEY (organization_id, project_id, property_id, environment_id, scan_id) REFERENCES public.scans(organization_id, project_id, property_id, environment_id, id) ON DELETE RESTRICT;


--
-- Name: audit_events fk_audit_events_same_org_actor; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT fk_audit_events_same_org_actor FOREIGN KEY (organization_id, actor_membership_id) REFERENCES public.memberships(organization_id, id) ON DELETE RESTRICT;


--
-- Name: audit_target_tombstones fk_audit_tombstones_tenant_workflow; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_target_tombstones
    ADD CONSTRAINT fk_audit_tombstones_tenant_workflow FOREIGN KEY (organization_id, deletion_workflow_id) REFERENCES public.resource_deletion_workflows(organization_id, id) ON DELETE RESTRICT;


--
-- Name: authorization_scope_references fk_authorization_property_scope_same_org_project; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authorization_scope_references
    ADD CONSTRAINT fk_authorization_property_scope_same_org_project FOREIGN KEY (organization_id, project_id, project_scope_type) REFERENCES public.authorization_scope_references(organization_id, id, scope_type) ON DELETE RESTRICT;


--
-- Name: billing_subscription_changes fk_billing_changes_tenant_requester; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_subscription_changes
    ADD CONSTRAINT fk_billing_changes_tenant_requester FOREIGN KEY (organization_id, requested_by_membership_id) REFERENCES public.memberships(organization_id, id) ON DELETE RESTRICT;


--
-- Name: billing_subscription_changes fk_billing_changes_tenant_subscription; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_subscription_changes
    ADD CONSTRAINT fk_billing_changes_tenant_subscription FOREIGN KEY (organization_id, subscription_id) REFERENCES public.subscriptions(organization_id, id) ON DELETE RESTRICT;


--
-- Name: billing_checkout_sessions fk_billing_checkouts_tenant_customer; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_checkout_sessions
    ADD CONSTRAINT fk_billing_checkouts_tenant_customer FOREIGN KEY (billing_customer_id, organization_id, provider, environment) REFERENCES public.billing_customers(id, organization_id, provider, environment) ON DELETE RESTRICT;


--
-- Name: billing_checkout_sessions fk_billing_checkouts_tenant_membership; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_checkout_sessions
    ADD CONSTRAINT fk_billing_checkouts_tenant_membership FOREIGN KEY (organization_id, actor_membership_id) REFERENCES public.memberships(organization_id, id) ON DELETE RESTRICT;


--
-- Name: billing_reconciliation_runs fk_billing_reconciliations_tenant_subscription; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_reconciliation_runs
    ADD CONSTRAINT fk_billing_reconciliations_tenant_subscription FOREIGN KEY (organization_id, subscription_id) REFERENCES public.subscriptions(organization_id, id) ON DELETE RESTRICT;


--
-- Name: billing_webhook_events fk_billing_webhooks_tenant_subscription; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_webhook_events
    ADD CONSTRAINT fk_billing_webhooks_tenant_subscription FOREIGN KEY (organization_id, subscription_id) REFERENCES public.subscriptions(organization_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_fetch_permits fk_crawl_fetch_permits_exact_frontier; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_fetch_permits
    ADD CONSTRAINT fk_crawl_fetch_permits_exact_frontier FOREIGN KEY (scan_id, crawl_url_id) REFERENCES public.crawl_urls(scan_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_fetch_permits fk_crawl_fetch_permits_exact_scan; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_fetch_permits
    ADD CONSTRAINT fk_crawl_fetch_permits_exact_scan FOREIGN KEY (organization_id, project_id, property_id, environment_id, scan_id) REFERENCES public.scans(organization_id, project_id, property_id, environment_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_fetch_results fk_crawl_fetch_results_exact_artifact; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_fetch_results
    ADD CONSTRAINT fk_crawl_fetch_results_exact_artifact FOREIGN KEY (organization_id, project_id, property_id, environment_id, scan_id, artifact_id) REFERENCES public.artifacts(organization_id, project_id, property_id, environment_id, scan_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_fetch_results fk_crawl_fetch_results_exact_scan; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_fetch_results
    ADD CONSTRAINT fk_crawl_fetch_results_exact_scan FOREIGN KEY (organization_id, project_id, property_id, environment_id, scan_id) REFERENCES public.scans(organization_id, project_id, property_id, environment_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_fetch_results fk_crawl_fetch_results_same_scan_url; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_fetch_results
    ADD CONSTRAINT fk_crawl_fetch_results_same_scan_url FOREIGN KEY (scan_id, crawl_url_id) REFERENCES public.crawl_urls(scan_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_links fk_crawl_links_exact_snapshot; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_links
    ADD CONSTRAINT fk_crawl_links_exact_snapshot FOREIGN KEY (organization_id, project_id, property_id, environment_id, scan_id, page_snapshot_id) REFERENCES public.crawl_page_snapshots(organization_id, project_id, property_id, environment_id, scan_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_links fk_crawl_links_same_scan_destination; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_links
    ADD CONSTRAINT fk_crawl_links_same_scan_destination FOREIGN KEY (scan_id, destination_crawl_url_id) REFERENCES public.crawl_urls(scan_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_links fk_crawl_links_same_scan_source; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_links
    ADD CONSTRAINT fk_crawl_links_same_scan_source FOREIGN KEY (scan_id, source_crawl_url_id) REFERENCES public.crawl_urls(scan_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_page_facts fk_crawl_page_facts_exact_snapshot; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_page_facts
    ADD CONSTRAINT fk_crawl_page_facts_exact_snapshot FOREIGN KEY (organization_id, project_id, property_id, environment_id, scan_id, page_snapshot_id) REFERENCES public.crawl_page_snapshots(organization_id, project_id, property_id, environment_id, scan_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_page_renders fk_crawl_page_renders_exact_dom_artifact; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_page_renders
    ADD CONSTRAINT fk_crawl_page_renders_exact_dom_artifact FOREIGN KEY (organization_id, project_id, property_id, environment_id, scan_id, rendered_dom_artifact_id) REFERENCES public.artifacts(organization_id, project_id, property_id, environment_id, scan_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_page_renders fk_crawl_page_renders_exact_scan; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_page_renders
    ADD CONSTRAINT fk_crawl_page_renders_exact_scan FOREIGN KEY (organization_id, project_id, property_id, environment_id, scan_id) REFERENCES public.scans(organization_id, project_id, property_id, environment_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_page_renders fk_crawl_page_renders_exact_screenshot_artifact; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_page_renders
    ADD CONSTRAINT fk_crawl_page_renders_exact_screenshot_artifact FOREIGN KEY (organization_id, project_id, property_id, environment_id, scan_id, screenshot_artifact_id) REFERENCES public.artifacts(organization_id, project_id, property_id, environment_id, scan_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_page_renders fk_crawl_page_renders_exact_snapshot; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_page_renders
    ADD CONSTRAINT fk_crawl_page_renders_exact_snapshot FOREIGN KEY (organization_id, project_id, property_id, environment_id, scan_id, page_snapshot_id) REFERENCES public.crawl_page_snapshots(organization_id, project_id, property_id, environment_id, scan_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_page_renders fk_crawl_page_renders_exact_source_fact; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_page_renders
    ADD CONSTRAINT fk_crawl_page_renders_exact_source_fact FOREIGN KEY (organization_id, project_id, property_id, environment_id, scan_id, page_fact_id) REFERENCES public.crawl_page_facts(organization_id, project_id, property_id, environment_id, scan_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_page_snapshots fk_crawl_page_snapshots_exact_artifact; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_page_snapshots
    ADD CONSTRAINT fk_crawl_page_snapshots_exact_artifact FOREIGN KEY (organization_id, project_id, property_id, environment_id, scan_id, artifact_id) REFERENCES public.artifacts(organization_id, project_id, property_id, environment_id, scan_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_page_snapshots fk_crawl_page_snapshots_exact_scan; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_page_snapshots
    ADD CONSTRAINT fk_crawl_page_snapshots_exact_scan FOREIGN KEY (organization_id, project_id, property_id, environment_id, scan_id) REFERENCES public.scans(organization_id, project_id, property_id, environment_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_page_snapshots fk_crawl_page_snapshots_same_scan_fetch; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_page_snapshots
    ADD CONSTRAINT fk_crawl_page_snapshots_same_scan_fetch FOREIGN KEY (scan_id, crawl_fetch_result_id) REFERENCES public.crawl_fetch_results(scan_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_page_snapshots fk_crawl_page_snapshots_same_scan_url; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_page_snapshots
    ADD CONSTRAINT fk_crawl_page_snapshots_same_scan_url FOREIGN KEY (scan_id, crawl_url_id) REFERENCES public.crawl_urls(scan_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_policy_sets fk_crawl_policy_sets_environment; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_policy_sets
    ADD CONSTRAINT fk_crawl_policy_sets_environment FOREIGN KEY (organization_id, project_id, property_id, environment_id) REFERENCES public.property_environments(organization_id, project_id, property_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_policy_snapshots fk_crawl_policy_snapshots_exact_scan; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_policy_snapshots
    ADD CONSTRAINT fk_crawl_policy_snapshots_exact_scan FOREIGN KEY (organization_id, project_id, property_id, environment_id, scan_id) REFERENCES public.scans(organization_id, project_id, property_id, environment_id, id) ON DELETE RESTRICT NOT VALID;


--
-- Name: crawl_policy_snapshots fk_crawl_policy_snapshots_policy_version; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_policy_snapshots
    ADD CONSTRAINT fk_crawl_policy_snapshots_policy_version FOREIGN KEY (organization_id, project_id, property_id, environment_id, crawl_policy_version_id) REFERENCES public.crawl_policy_versions(organization_id, project_id, property_id, environment_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_policy_versions fk_crawl_policy_versions_policy_set; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_policy_versions
    ADD CONSTRAINT fk_crawl_policy_versions_policy_set FOREIGN KEY (crawl_policy_set_id, organization_id, project_id, property_id, environment_id) REFERENCES public.crawl_policy_sets(id, organization_id, project_id, property_id, environment_id) ON DELETE RESTRICT;


--
-- Name: crawl_policy_versions fk_crawl_policy_versions_tenant_actor; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_policy_versions
    ADD CONSTRAINT fk_crawl_policy_versions_tenant_actor FOREIGN KEY (organization_id, created_by_membership_id) REFERENCES public.memberships(organization_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_pressure_states fk_crawl_pressure_states_disabled_by_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_pressure_states
    ADD CONSTRAINT fk_crawl_pressure_states_disabled_by_user FOREIGN KEY (disabled_by_user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: crawl_pressure_states fk_crawl_pressure_states_exact_scan; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_pressure_states
    ADD CONSTRAINT fk_crawl_pressure_states_exact_scan FOREIGN KEY (organization_id, project_id, property_id, environment_id, scan_id) REFERENCES public.scans(organization_id, project_id, property_id, environment_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_rendered_page_facts fk_crawl_rendered_facts_exact_render; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_rendered_page_facts
    ADD CONSTRAINT fk_crawl_rendered_facts_exact_render FOREIGN KEY (organization_id, project_id, property_id, environment_id, scan_id, page_render_id) REFERENCES public.crawl_page_renders(organization_id, project_id, property_id, environment_id, scan_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_rendered_links fk_crawl_rendered_links_exact_render; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_rendered_links
    ADD CONSTRAINT fk_crawl_rendered_links_exact_render FOREIGN KEY (organization_id, project_id, property_id, environment_id, scan_id, page_render_id) REFERENCES public.crawl_page_renders(organization_id, project_id, property_id, environment_id, scan_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_robots_snapshots fk_crawl_robots_snapshots_exact_scan; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_robots_snapshots
    ADD CONSTRAINT fk_crawl_robots_snapshots_exact_scan FOREIGN KEY (organization_id, project_id, property_id, environment_id, scan_id) REFERENCES public.scans(organization_id, project_id, property_id, environment_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_scan_executions fk_crawl_scan_executions_exact_scan; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_scan_executions
    ADD CONSTRAINT fk_crawl_scan_executions_exact_scan FOREIGN KEY (organization_id, project_id, property_id, environment_id, scan_id) REFERENCES public.scans(organization_id, project_id, property_id, environment_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_scan_usage_operations fk_crawl_scan_usage_operations_exact_scan; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_scan_usage_operations
    ADD CONSTRAINT fk_crawl_scan_usage_operations_exact_scan FOREIGN KEY (organization_id, project_id, property_id, environment_id, scan_id) REFERENCES public.scans(organization_id, project_id, property_id, environment_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_scan_usage_operations fk_crawl_scan_usage_operations_tenant_allocation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_scan_usage_operations
    ADD CONSTRAINT fk_crawl_scan_usage_operations_tenant_allocation FOREIGN KEY (organization_id, usage_quota_allocation_id) REFERENCES public.usage_quota_allocations(organization_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_scan_usage_operations fk_crawl_scan_usage_operations_tenant_event; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_scan_usage_operations
    ADD CONSTRAINT fk_crawl_scan_usage_operations_tenant_event FOREIGN KEY (organization_id, usage_event_id) REFERENCES public.usage_events(organization_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_sitemap_discoveries fk_crawl_sitemap_discoveries_exact_scan; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_sitemap_discoveries
    ADD CONSTRAINT fk_crawl_sitemap_discoveries_exact_scan FOREIGN KEY (organization_id, project_id, property_id, environment_id, scan_id) REFERENCES public.scans(organization_id, project_id, property_id, environment_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_sitemap_entries fk_crawl_sitemap_entries_exact_scan; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_sitemap_entries
    ADD CONSTRAINT fk_crawl_sitemap_entries_exact_scan FOREIGN KEY (organization_id, project_id, property_id, environment_id, scan_id) REFERENCES public.scans(organization_id, project_id, property_id, environment_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_sitemap_entries fk_crawl_sitemap_entries_same_scan_child; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_sitemap_entries
    ADD CONSTRAINT fk_crawl_sitemap_entries_same_scan_child FOREIGN KEY (scan_id, child_sitemap_file_id) REFERENCES public.crawl_sitemap_files(scan_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_sitemap_entries fk_crawl_sitemap_entries_same_scan_file; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_sitemap_entries
    ADD CONSTRAINT fk_crawl_sitemap_entries_same_scan_file FOREIGN KEY (scan_id, sitemap_file_id) REFERENCES public.crawl_sitemap_files(scan_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_sitemap_entries fk_crawl_sitemap_entries_same_scan_url; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_sitemap_entries
    ADD CONSTRAINT fk_crawl_sitemap_entries_same_scan_url FOREIGN KEY (scan_id, crawl_url_id) REFERENCES public.crawl_urls(scan_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_sitemap_files fk_crawl_sitemap_files_exact_scan; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_sitemap_files
    ADD CONSTRAINT fk_crawl_sitemap_files_exact_scan FOREIGN KEY (organization_id, project_id, property_id, environment_id, scan_id) REFERENCES public.scans(organization_id, project_id, property_id, environment_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_sitemap_files fk_crawl_sitemap_files_same_scan_discovery; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_sitemap_files
    ADD CONSTRAINT fk_crawl_sitemap_files_same_scan_discovery FOREIGN KEY (scan_id, sitemap_discovery_id) REFERENCES public.crawl_sitemap_discoveries(scan_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_sitemap_files fk_crawl_sitemap_files_same_scan_parent; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_sitemap_files
    ADD CONSTRAINT fk_crawl_sitemap_files_same_scan_parent FOREIGN KEY (scan_id, parent_sitemap_file_id) REFERENCES public.crawl_sitemap_files(scan_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_urls fk_crawl_urls_exact_scan; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_urls
    ADD CONSTRAINT fk_crawl_urls_exact_scan FOREIGN KEY (organization_id, project_id, property_id, environment_id, scan_id) REFERENCES public.scans(organization_id, project_id, property_id, environment_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_urls fk_crawl_urls_same_scan_discovery; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_urls
    ADD CONSTRAINT fk_crawl_urls_same_scan_discovery FOREIGN KEY (scan_id, discovered_from_id) REFERENCES public.crawl_urls(scan_id, id) ON DELETE RESTRICT;


--
-- Name: crawl_urls fk_crawl_urls_same_scan_fetch_result; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_urls
    ADD CONSTRAINT fk_crawl_urls_same_scan_fetch_result FOREIGN KEY (scan_id, fetch_result_id) REFERENCES public.crawl_fetch_results(scan_id, id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: organization_ownerships fk_current_ownership_active_membership; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_ownerships
    ADD CONSTRAINT fk_current_ownership_active_membership FOREIGN KEY (organization_id, membership_id, membership_status) REFERENCES public.memberships(organization_id, id, status) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: resource_deletion_stage_executions fk_deletion_stages_tenant_workflow; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_deletion_stage_executions
    ADD CONSTRAINT fk_deletion_stages_tenant_workflow FOREIGN KEY (organization_id, resource_deletion_workflow_id) REFERENCES public.resource_deletion_workflows(organization_id, id) ON DELETE CASCADE;


--
-- Name: resource_deletion_workflows fk_deletion_workflows_tenant_requester; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_deletion_workflows
    ADD CONSTRAINT fk_deletion_workflows_tenant_requester FOREIGN KEY (organization_id, requested_by_membership_id) REFERENCES public.memberships(organization_id, id) ON DELETE RESTRICT;


--
-- Name: domain_verifications fk_domain_verifications_tenant_environment; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_verifications
    ADD CONSTRAINT fk_domain_verifications_tenant_environment FOREIGN KEY (organization_id, project_id, property_id, environment_id) REFERENCES public.property_environments(organization_id, project_id, property_id, id) ON DELETE RESTRICT;


--
-- Name: domain_verifications fk_domain_verifications_tenant_integration; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_verifications
    ADD CONSTRAINT fk_domain_verifications_tenant_integration FOREIGN KEY (organization_id, integration_connection_id) REFERENCES public.integration_connections(organization_id, id) ON DELETE RESTRICT;


--
-- Name: domain_verifications fk_domain_verifications_tenant_issuer; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_verifications
    ADD CONSTRAINT fk_domain_verifications_tenant_issuer FOREIGN KEY (organization_id, issued_by_membership_id) REFERENCES public.memberships(organization_id, id) ON DELETE RESTRICT;


--
-- Name: entitlement_subscription_contexts fk_entitlement_contexts_subscription_identity; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entitlement_subscription_contexts
    ADD CONSTRAINT fk_entitlement_contexts_subscription_identity FOREIGN KEY (organization_id, subscription_id, plan_version_id) REFERENCES public.subscriptions(organization_id, id, plan_version_id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: organization_entitlement_overrides fk_entitlement_overrides_definition_type; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_entitlement_overrides
    ADD CONSTRAINT fk_entitlement_overrides_definition_type FOREIGN KEY (entitlement_definition_id, value_type) REFERENCES public.entitlement_definitions(id, value_type) ON DELETE RESTRICT;


--
-- Name: organization_entitlement_overrides fk_entitlement_overrides_same_org_creator; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_entitlement_overrides
    ADD CONSTRAINT fk_entitlement_overrides_same_org_creator FOREIGN KEY (organization_id, created_by_membership_id) REFERENCES public.memberships(organization_id, id) ON DELETE RESTRICT;


--
-- Name: organization_entitlement_overrides fk_entitlement_overrides_same_org_revoker; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_entitlement_overrides
    ADD CONSTRAINT fk_entitlement_overrides_same_org_revoker FOREIGN KEY (organization_id, revoked_by_membership_id) REFERENCES public.memberships(organization_id, id) ON DELETE RESTRICT;


--
-- Name: integration_connections fk_integration_connections_tenant_member; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_connections
    ADD CONSTRAINT fk_integration_connections_tenant_member FOREIGN KEY (organization_id, connected_by_membership_id) REFERENCES public.memberships(organization_id, id) ON DELETE RESTRICT;


--
-- Name: invitations fk_invitations_same_org_acceptor; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT fk_invitations_same_org_acceptor FOREIGN KEY (organization_id, accepted_by_membership_id) REFERENCES public.memberships(organization_id, id) ON DELETE RESTRICT;


--
-- Name: invitations fk_invitations_same_org_inviter; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT fk_invitations_same_org_inviter FOREIGN KEY (organization_id, invited_by_membership_id) REFERENCES public.memberships(organization_id, id) ON DELETE RESTRICT;


--
-- Name: ios_property_configs fk_ios_property_configs_typed_property; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ios_property_configs
    ADD CONSTRAINT fk_ios_property_configs_typed_property FOREIGN KEY (organization_id, project_id, property_id, property_kind, configuration_version) REFERENCES public.properties(organization_id, project_id, id, kind, configuration_version) ON DELETE RESTRICT;


--
-- Name: organizations fk_organizations_same_active_ownership; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT fk_organizations_same_active_ownership FOREIGN KEY (id, current_ownership_id, current_ownership_active) REFERENCES public.organization_ownerships(organization_id, id, current) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: organization_ownerships fk_ownerships_same_organization_membership; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_ownerships
    ADD CONSTRAINT fk_ownerships_same_organization_membership FOREIGN KEY (organization_id, membership_id) REFERENCES public.memberships(organization_id, id) ON DELETE RESTRICT;


--
-- Name: plan_entitlements fk_plan_entitlements_definition_type; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plan_entitlements
    ADD CONSTRAINT fk_plan_entitlements_definition_type FOREIGN KEY (entitlement_definition_id, value_type) REFERENCES public.entitlement_definitions(id, value_type) ON DELETE RESTRICT;


--
-- Name: project_onboarding_drafts fk_project_onboarding_drafts_tenant_actor; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_onboarding_drafts
    ADD CONSTRAINT fk_project_onboarding_drafts_tenant_actor FOREIGN KEY (organization_id, actor_membership_id) REFERENCES public.memberships(organization_id, id) ON DELETE CASCADE;


--
-- Name: projects fk_projects_exact_deletion_workflow; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT fk_projects_exact_deletion_workflow FOREIGN KEY (organization_id, deletion_workflow_id, authorization_scope_type, id) REFERENCES public.resource_deletion_workflows(organization_id, id, target_type, target_id) ON DELETE RESTRICT;


--
-- Name: projects fk_projects_same_org_authorization_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT fk_projects_same_org_authorization_scope FOREIGN KEY (organization_id, id, authorization_scope_type) REFERENCES public.authorization_scope_references(organization_id, id, scope_type) ON DELETE RESTRICT;


--
-- Name: properties fk_properties_exact_deletion_workflow; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.properties
    ADD CONSTRAINT fk_properties_exact_deletion_workflow FOREIGN KEY (organization_id, deletion_workflow_id, authorization_scope_type, id) REFERENCES public.resource_deletion_workflows(organization_id, id, target_type, target_id) ON DELETE RESTRICT;


--
-- Name: properties fk_properties_same_org_project; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.properties
    ADD CONSTRAINT fk_properties_same_org_project FOREIGN KEY (organization_id, project_id) REFERENCES public.projects(organization_id, id) ON DELETE RESTRICT;


--
-- Name: properties fk_properties_same_scope_hierarchy; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.properties
    ADD CONSTRAINT fk_properties_same_scope_hierarchy FOREIGN KEY (organization_id, id, authorization_scope_type, project_id, authorization_project_scope_type) REFERENCES public.authorization_scope_references(organization_id, id, scope_type, project_id, project_scope_type) ON DELETE RESTRICT;


--
-- Name: property_environments fk_property_environments_typed_property; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.property_environments
    ADD CONSTRAINT fk_property_environments_typed_property FOREIGN KEY (organization_id, project_id, property_id, property_kind, configuration_version) REFERENCES public.properties(organization_id, project_id, id, kind, configuration_version) ON DELETE RESTRICT;


--
-- Name: billing_plan_provider_mappings fk_rails_0b34a5e891; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_plan_provider_mappings
    ADD CONSTRAINT fk_rails_0b34a5e891 FOREIGN KEY (plan_version_id) REFERENCES public.plan_versions(id) ON DELETE RESTRICT;


--
-- Name: invitations fk_rails_0fe4c14f0e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT fk_rails_0fe4c14f0e FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: subscriptions fk_rails_1302dfcd89; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT fk_rails_1302dfcd89 FOREIGN KEY (plan_version_id) REFERENCES public.plan_versions(id) ON DELETE RESTRICT;


--
-- Name: usage_windows fk_rails_2155e9a466; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_windows
    ADD CONSTRAINT fk_rails_2155e9a466 FOREIGN KEY (usage_meter_definition_id) REFERENCES public.usage_meter_definitions(id) ON DELETE RESTRICT;


--
-- Name: entitlement_subscription_contexts fk_rails_244e7733dc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entitlement_subscription_contexts
    ADD CONSTRAINT fk_rails_244e7733dc FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: crawl_pressure_states fk_rails_2bebbc3e68; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_pressure_states
    ADD CONSTRAINT fk_rails_2bebbc3e68 FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: audit_events fk_rails_2e3720791c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT fk_rails_2e3720791c FOREIGN KEY (actor_user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: roles fk_rails_2f99738edd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT fk_rails_2f99738edd FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: plan_catalog_access_grants fk_rails_301521b623; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plan_catalog_access_grants
    ADD CONSTRAINT fk_rails_301521b623 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: billing_support_access_grants fk_rails_33d94711b6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_support_access_grants
    ADD CONSTRAINT fk_rails_33d94711b6 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: subscriptions fk_rails_364213cc3e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT fk_rails_364213cc3e FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: crawl_control_access_grants fk_rails_405dee28d0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crawl_control_access_grants
    ADD CONSTRAINT fk_rails_405dee28d0 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: role_permissions fk_rails_439e640a3f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT fk_rails_439e640a3f FOREIGN KEY (permission_id) REFERENCES public.permissions(id) ON DELETE RESTRICT;


--
-- Name: properties fk_rails_467fb8a84a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.properties
    ADD CONSTRAINT fk_rails_467fb8a84a FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: authorization_scope_references fk_rails_4c9101a77e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authorization_scope_references
    ADD CONSTRAINT fk_rails_4c9101a77e FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: organization_ownerships fk_rails_4c966f3821; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_ownerships
    ADD CONSTRAINT fk_rails_4c966f3821 FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: scans fk_rails_4eb5a432df; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scans
    ADD CONSTRAINT fk_rails_4eb5a432df FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: identities fk_rails_5373344100; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identities
    ADD CONSTRAINT fk_rails_5373344100 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: billing_subscription_changes fk_rails_5ee03663be; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_subscription_changes
    ADD CONSTRAINT fk_rails_5ee03663be FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: role_permissions fk_rails_60126080bd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT fk_rails_60126080bd FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE RESTRICT;


--
-- Name: billing_subscription_changes fk_rails_60f99cfd43; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_subscription_changes
    ADD CONSTRAINT fk_rails_60f99cfd43 FOREIGN KEY (target_plan_version_id) REFERENCES public.plan_versions(id) ON DELETE RESTRICT;


--
-- Name: billing_subscription_changes fk_rails_61b184c80d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_subscription_changes
    ADD CONSTRAINT fk_rails_61b184c80d FOREIGN KEY (from_plan_version_id) REFERENCES public.plan_versions(id) ON DELETE RESTRICT;


--
-- Name: memberships fk_rails_64267aab58; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT fk_rails_64267aab58 FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: resource_deletion_workflows fk_rails_6be5fa48d5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_deletion_workflows
    ADD CONSTRAINT fk_rails_6be5fa48d5 FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: billing_customers fk_rails_6d4927c1b8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_customers
    ADD CONSTRAINT fk_rails_6d4927c1b8 FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: billing_reconciliation_runs fk_rails_71bf2bef10; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_reconciliation_runs
    ADD CONSTRAINT fk_rails_71bf2bef10 FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: billing_webhook_events fk_rails_79fcf94956; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_webhook_events
    ADD CONSTRAINT fk_rails_79fcf94956 FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: sessions fk_rails_850fa66024; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_850fa66024 FOREIGN KEY (rotated_from_id) REFERENCES public.sessions(id) ON DELETE RESTRICT;


--
-- Name: entitlement_subscription_contexts fk_rails_8f660453e5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entitlement_subscription_contexts
    ADD CONSTRAINT fk_rails_8f660453e5 FOREIGN KEY (plan_version_id) REFERENCES public.plan_versions(id) ON DELETE RESTRICT;


--
-- Name: memberships fk_rails_99326fb65d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT fk_rails_99326fb65d FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: projects fk_rails_9aee26923d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT fk_rails_9aee26923d FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: plan_version_snapshot_references fk_rails_9d09607450; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plan_version_snapshot_references
    ADD CONSTRAINT fk_rails_9d09607450 FOREIGN KEY (plan_version_id) REFERENCES public.plan_versions(id) ON DELETE RESTRICT;


--
-- Name: audit_target_tombstones fk_rails_9f7537650a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_target_tombstones
    ADD CONSTRAINT fk_rails_9f7537650a FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: billing_checkout_sessions fk_rails_9f7df1dbb1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_checkout_sessions
    ADD CONSTRAINT fk_rails_9f7df1dbb1 FOREIGN KEY (plan_version_id) REFERENCES public.plan_versions(id) ON DELETE RESTRICT;


--
-- Name: integration_connections fk_rails_a9d88bf42e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_connections
    ADD CONSTRAINT fk_rails_a9d88bf42e FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: plan_versions fk_rails_ada72724a1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plan_versions
    ADD CONSTRAINT fk_rails_ada72724a1 FOREIGN KEY (plan_id) REFERENCES public.plans(id) ON DELETE RESTRICT;


--
-- Name: usage_quota_allocations fk_rails_b15c403238; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_quota_allocations
    ADD CONSTRAINT fk_rails_b15c403238 FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: plan_entitlements fk_rails_b2e4cbe7bf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plan_entitlements
    ADD CONSTRAINT fk_rails_b2e4cbe7bf FOREIGN KEY (plan_version_id) REFERENCES public.plan_versions(id) ON DELETE RESTRICT;


--
-- Name: outbox_events fk_rails_b6cb24ddb3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.outbox_events
    ADD CONSTRAINT fk_rails_b6cb24ddb3 FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: usage_quota_reservation_operations fk_rails_b94ce8e8be; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_quota_reservation_operations
    ADD CONSTRAINT fk_rails_b94ce8e8be FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: billing_reconciliation_runs fk_rails_b976ff4fef; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_reconciliation_runs
    ADD CONSTRAINT fk_rails_b976ff4fef FOREIGN KEY (requested_by_user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: usage_quota_reservations fk_rails_bdb6f3383a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_quota_reservations
    ADD CONSTRAINT fk_rails_bdb6f3383a FOREIGN KEY (plan_version_id) REFERENCES public.plan_versions(id) ON DELETE RESTRICT;


--
-- Name: audit_events fk_rails_be0ed9e37f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT fk_rails_be0ed9e37f FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: project_onboarding_drafts fk_rails_c02a837188; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_onboarding_drafts
    ADD CONSTRAINT fk_rails_c02a837188 FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: usage_windows fk_rails_c8db8dda1e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_windows
    ADD CONSTRAINT fk_rails_c8db8dda1e FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: oauth_transactions fk_rails_cbf62b83df; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_transactions
    ADD CONSTRAINT fk_rails_cbf62b83df FOREIGN KEY (link_session_id) REFERENCES public.sessions(id) ON DELETE RESTRICT;


--
-- Name: usage_meter_rates fk_rails_d068f75899; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_meter_rates
    ADD CONSTRAINT fk_rails_d068f75899 FOREIGN KEY (usage_meter_definition_id) REFERENCES public.usage_meter_definitions(id) ON DELETE RESTRICT;


--
-- Name: usage_quota_reservations fk_rails_d5b5f582c2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_quota_reservations
    ADD CONSTRAINT fk_rails_d5b5f582c2 FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: role_assignments fk_rails_d5d049f535; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT fk_rails_d5d049f535 FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: usage_events fk_rails_dc5cb31f7a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_events
    ADD CONSTRAINT fk_rails_dc5cb31f7a FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: organization_slug_aliases fk_rails_dd2285ec0a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_slug_aliases
    ADD CONSTRAINT fk_rails_dd2285ec0a FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: teams fk_rails_f07f0bd66d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT fk_rails_f07f0bd66d FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: billing_checkout_sessions fk_rails_f3d794e9d6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_checkout_sessions
    ADD CONSTRAINT fk_rails_f3d794e9d6 FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: organizations fk_rails_f4c6fce826; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT fk_rails_f4c6fce826 FOREIGN KEY (current_ownership_id) REFERENCES public.organization_ownerships(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: team_memberships fk_rails_f815fd92e5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_memberships
    ADD CONSTRAINT fk_rails_f815fd92e5 FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: organization_entitlement_overrides fk_rails_ff84dda40a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_entitlement_overrides
    ADD CONSTRAINT fk_rails_ff84dda40a FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: role_assignments fk_role_assignments_role_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT fk_role_assignments_role_kind FOREIGN KEY (role_id, role_system) REFERENCES public.roles(id, system) ON DELETE RESTRICT;


--
-- Name: role_assignments fk_role_assignments_same_org_custom_role; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT fk_role_assignments_same_org_custom_role FOREIGN KEY (role_organization_id, role_id) REFERENCES public.roles(organization_id, id) ON DELETE RESTRICT;


--
-- Name: role_assignments fk_role_assignments_same_org_grantor; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT fk_role_assignments_same_org_grantor FOREIGN KEY (organization_id, granted_by_membership_id) REFERENCES public.memberships(organization_id, id) ON DELETE RESTRICT;


--
-- Name: role_assignments fk_role_assignments_same_org_membership; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT fk_role_assignments_same_org_membership FOREIGN KEY (organization_id, membership_grantee_id) REFERENCES public.memberships(organization_id, id) ON DELETE RESTRICT;


--
-- Name: role_assignments fk_role_assignments_same_org_revoker; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT fk_role_assignments_same_org_revoker FOREIGN KEY (organization_id, revoked_by_membership_id) REFERENCES public.memberships(organization_id, id) ON DELETE RESTRICT;


--
-- Name: role_assignments fk_role_assignments_same_org_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT fk_role_assignments_same_org_scope FOREIGN KEY (organization_id, scope_id, scope_type) REFERENCES public.authorization_scope_references(organization_id, id, scope_type) ON DELETE RESTRICT;


--
-- Name: role_assignments fk_role_assignments_same_org_team; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT fk_role_assignments_same_org_team FOREIGN KEY (organization_id, team_grantee_id) REFERENCES public.teams(organization_id, id) ON DELETE RESTRICT;


--
-- Name: scan_events fk_scan_events_exact_scan; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scan_events
    ADD CONSTRAINT fk_scan_events_exact_scan FOREIGN KEY (organization_id, project_id, property_id, environment_id, scan_id) REFERENCES public.scans(organization_id, project_id, property_id, environment_id, id) ON DELETE RESTRICT;


--
-- Name: scan_events fk_scan_events_tenant_actor; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scan_events
    ADD CONSTRAINT fk_scan_events_tenant_actor FOREIGN KEY (organization_id, actor_membership_id) REFERENCES public.memberships(organization_id, id) ON DELETE RESTRICT;


--
-- Name: scans fk_scans_exact_baseline; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scans
    ADD CONSTRAINT fk_scans_exact_baseline FOREIGN KEY (organization_id, project_id, property_id, environment_id, baseline_scan_id) REFERENCES public.scans(organization_id, project_id, property_id, environment_id, id) ON DELETE RESTRICT;


--
-- Name: scans fk_scans_exact_environment; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scans
    ADD CONSTRAINT fk_scans_exact_environment FOREIGN KEY (organization_id, project_id, property_id, environment_id) REFERENCES public.property_environments(organization_id, project_id, property_id, id) ON DELETE RESTRICT;


--
-- Name: scans fk_scans_exact_verification; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scans
    ADD CONSTRAINT fk_scans_exact_verification FOREIGN KEY (organization_id, project_id, property_id, environment_id, domain_verification_id) REFERENCES public.domain_verifications(organization_id, project_id, property_id, environment_id, id) ON DELETE RESTRICT;


--
-- Name: scans fk_scans_tenant_initiator; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scans
    ADD CONSTRAINT fk_scans_tenant_initiator FOREIGN KEY (organization_id, initiated_by_membership_id) REFERENCES public.memberships(organization_id, id) ON DELETE RESTRICT;


--
-- Name: scans fk_scans_tenant_quota_reservation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scans
    ADD CONSTRAINT fk_scans_tenant_quota_reservation FOREIGN KEY (organization_id, usage_quota_reservation_id) REFERENCES public.usage_quota_reservations(organization_id, id) ON DELETE RESTRICT;


--
-- Name: subscriptions fk_subscriptions_tenant_provider_customer; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT fk_subscriptions_tenant_provider_customer FOREIGN KEY (billing_customer_id, organization_id, provider, provider_environment) REFERENCES public.billing_customers(id, organization_id, provider, environment) ON DELETE RESTRICT;


--
-- Name: team_memberships fk_team_memberships_same_org_actor; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_memberships
    ADD CONSTRAINT fk_team_memberships_same_org_actor FOREIGN KEY (organization_id, added_by_membership_id) REFERENCES public.memberships(organization_id, id) ON DELETE RESTRICT;


--
-- Name: team_memberships fk_team_memberships_same_org_member; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_memberships
    ADD CONSTRAINT fk_team_memberships_same_org_member FOREIGN KEY (organization_id, membership_id) REFERENCES public.memberships(organization_id, id) ON DELETE RESTRICT;


--
-- Name: team_memberships fk_team_memberships_same_org_team; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_memberships
    ADD CONSTRAINT fk_team_memberships_same_org_team FOREIGN KEY (organization_id, team_id) REFERENCES public.teams(organization_id, id) ON DELETE RESTRICT;


--
-- Name: usage_events fk_usage_events_meter_rate; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_events
    ADD CONSTRAINT fk_usage_events_meter_rate FOREIGN KEY (usage_meter_definition_id, usage_meter_rate_id) REFERENCES public.usage_meter_rates(usage_meter_definition_id, id) ON DELETE RESTRICT;


--
-- Name: usage_events fk_usage_events_same_context_correction; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_events
    ADD CONSTRAINT fk_usage_events_same_context_correction FOREIGN KEY (organization_id, correction_of_event_id, usage_window_id, usage_meter_definition_id) REFERENCES public.usage_events(organization_id, id, usage_window_id, usage_meter_definition_id) ON DELETE RESTRICT;


--
-- Name: usage_events fk_usage_events_same_org_actor; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_events
    ADD CONSTRAINT fk_usage_events_same_org_actor FOREIGN KEY (organization_id, actor_membership_id) REFERENCES public.memberships(organization_id, id) ON DELETE RESTRICT;


--
-- Name: usage_events fk_usage_events_source_organization; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_events
    ADD CONSTRAINT fk_usage_events_source_organization FOREIGN KEY (source_organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: usage_events fk_usage_events_tenant_window_meter; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_events
    ADD CONSTRAINT fk_usage_events_tenant_window_meter FOREIGN KEY (organization_id, usage_window_id, usage_meter_definition_id) REFERENCES public.usage_windows(organization_id, id, usage_meter_definition_id) ON DELETE RESTRICT;


--
-- Name: usage_quota_allocations fk_usage_quota_allocations_meter_rate; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_quota_allocations
    ADD CONSTRAINT fk_usage_quota_allocations_meter_rate FOREIGN KEY (usage_meter_definition_id, usage_meter_rate_id) REFERENCES public.usage_meter_rates(usage_meter_definition_id, id) ON DELETE RESTRICT;


--
-- Name: usage_quota_allocations fk_usage_quota_allocations_tenant_event; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_quota_allocations
    ADD CONSTRAINT fk_usage_quota_allocations_tenant_event FOREIGN KEY (organization_id, usage_event_id) REFERENCES public.usage_events(organization_id, id) ON DELETE RESTRICT;


--
-- Name: usage_quota_allocations fk_usage_quota_allocations_tenant_reservation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_quota_allocations
    ADD CONSTRAINT fk_usage_quota_allocations_tenant_reservation FOREIGN KEY (organization_id, usage_quota_reservation_id) REFERENCES public.usage_quota_reservations(organization_id, id) ON DELETE RESTRICT;


--
-- Name: usage_quota_allocations fk_usage_quota_allocations_tenant_window; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_quota_allocations
    ADD CONSTRAINT fk_usage_quota_allocations_tenant_window FOREIGN KEY (organization_id, usage_window_id, usage_meter_definition_id) REFERENCES public.usage_windows(organization_id, id, usage_meter_definition_id) ON DELETE RESTRICT;


--
-- Name: usage_quota_reservation_operations fk_usage_quota_operations_tenant_event; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_quota_reservation_operations
    ADD CONSTRAINT fk_usage_quota_operations_tenant_event FOREIGN KEY (organization_id, usage_event_id) REFERENCES public.usage_events(organization_id, id) ON DELETE RESTRICT;


--
-- Name: usage_quota_reservation_operations fk_usage_quota_operations_tenant_reservation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_quota_reservation_operations
    ADD CONSTRAINT fk_usage_quota_operations_tenant_reservation FOREIGN KEY (organization_id, usage_quota_reservation_id) REFERENCES public.usage_quota_reservations(organization_id, id) ON DELETE RESTRICT;


--
-- Name: usage_quota_reservations fk_usage_quota_reservations_entitlement_override; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_quota_reservations
    ADD CONSTRAINT fk_usage_quota_reservations_entitlement_override FOREIGN KEY (entitlement_override_id) REFERENCES public.organization_entitlement_overrides(id) ON DELETE RESTRICT;


--
-- Name: usage_quota_reservations fk_usage_quota_reservations_finalized_event; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_quota_reservations
    ADD CONSTRAINT fk_usage_quota_reservations_finalized_event FOREIGN KEY (organization_id, finalized_usage_event_id, usage_window_id, usage_meter_definition_id) REFERENCES public.usage_events(organization_id, id, usage_window_id, usage_meter_definition_id) ON DELETE RESTRICT;


--
-- Name: usage_quota_reservations fk_usage_quota_reservations_meter_rate; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_quota_reservations
    ADD CONSTRAINT fk_usage_quota_reservations_meter_rate FOREIGN KEY (usage_meter_definition_id, usage_meter_rate_id) REFERENCES public.usage_meter_rates(usage_meter_definition_id, id) ON DELETE RESTRICT;


--
-- Name: usage_quota_reservations fk_usage_quota_reservations_source_organization; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_quota_reservations
    ADD CONSTRAINT fk_usage_quota_reservations_source_organization FOREIGN KEY (source_organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: usage_quota_reservations fk_usage_quota_reservations_subscription_snapshot; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_quota_reservations
    ADD CONSTRAINT fk_usage_quota_reservations_subscription_snapshot FOREIGN KEY (organization_id, subscription_id) REFERENCES public.subscriptions(organization_id, id) ON DELETE RESTRICT;


--
-- Name: usage_quota_reservations fk_usage_quota_reservations_tenant_window_meter; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_quota_reservations
    ADD CONSTRAINT fk_usage_quota_reservations_tenant_window_meter FOREIGN KEY (organization_id, usage_window_id, usage_meter_definition_id) REFERENCES public.usage_windows(organization_id, id, usage_meter_definition_id) ON DELETE RESTRICT;


--
-- Name: usage_windows fk_usage_windows_plan_version; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_windows
    ADD CONSTRAINT fk_usage_windows_plan_version FOREIGN KEY (plan_version_id) REFERENCES public.plan_versions(id) ON DELETE RESTRICT;


--
-- Name: usage_windows fk_usage_windows_subscription_snapshot; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_windows
    ADD CONSTRAINT fk_usage_windows_subscription_snapshot FOREIGN KEY (organization_id, subscription_id) REFERENCES public.subscriptions(organization_id, id) ON DELETE RESTRICT;


--
-- Name: domain_verification_attempts fk_verification_attempts_tenant_challenge; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_verification_attempts
    ADD CONSTRAINT fk_verification_attempts_tenant_challenge FOREIGN KEY (organization_id, project_id, property_id, environment_id, domain_verification_id) REFERENCES public.domain_verifications(organization_id, project_id, property_id, environment_id, id) ON DELETE RESTRICT;


--
-- Name: website_property_configs fk_website_property_configs_typed_property; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.website_property_configs
    ADD CONSTRAINT fk_website_property_configs_typed_property FOREIGN KEY (organization_id, project_id, property_id, property_kind, configuration_version) REFERENCES public.properties(organization_id, project_id, id, kind, configuration_version) ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260904158000'),
('20260904157000'),
('20260904156000'),
('20260904155000'),
('20260904154000'),
('20260904153000'),
('20260904152000'),
('20260904151000'),
('20260904150000'),
('20260904149000'),
('20260904148000'),
('20260904147000'),
('20260904146000'),
('20260904145000'),
('20260904144000'),
('20260904143000'),
('20260904142000'),
('20260904141000'),
('20260904140000'),
('20260904133000'),
('20260904131000'),
('20260904130000'),
('20260904123000'),
('20260904102000'),
('20260904101000'),
('20260904100000'),
('20260904095000'),
('20260904094000'),
('20260904093000'),
('20260904092000'),
('20260904091000'),
('20260904090000'),
('20260904088000'),
('20260904086000'),
('20260904084000'),
('20260904082000'),
('20260904080000'),
('20260904075000'),
('20260904073000'),
('20260904071000'),
('20260904065000'),
('20260904063000'),
('20260904061000'),
('20260904055000'),
('20260904053500'),
('20260904051500'),
('20260904042000'),
('20260904034000'),
('20260904033000'),
('20260904012600');
