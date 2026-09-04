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
    NEW.expires_at < OLD.expires_at THEN
    RAISE EXCEPTION 'usage quota reservation transition is invalid' USING ERRCODE = '23514';
  END IF;
  IF NEW.state = 'finalized' AND NEW.consumed_quantity > 0 AND NOT EXISTS (
    SELECT 1 FROM usage_events event
    WHERE event.id = NEW.finalized_usage_event_id
      AND event.organization_id = NEW.organization_id
      AND event.usage_window_id = NEW.usage_window_id
      AND event.usage_meter_definition_id = NEW.usage_meter_definition_id
      AND event.usage_meter_rate_id = NEW.usage_meter_rate_id
      AND event.source_type = NEW.source_type AND event.source_id = NEW.source_id
      AND event.billed_quantity = NEW.consumed_quantity
  ) THEN
    RAISE EXCEPTION 'usage quota finalization event is inconsistent' USING ERRCODE = '23514';
  END IF;
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
-- Name: prevent_domain_verification_attempt_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_domain_verification_attempt_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
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
    OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'domain verification binding cannot be changed';
  END IF;
  RETURN NEW;
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
    CONSTRAINT billing_reconciliations_environment_allowlist CHECK (((environment)::text = ANY ((ARRAY['development'::character varying, 'test'::character varying, 'staging'::character varying, 'production'::character varying])::text[]))),
    CONSTRAINT billing_reconciliations_lifecycle_shape CHECK (((((state)::text = 'queued'::text) AND (attempt_count = 0) AND (started_at IS NULL) AND (completed_at IS NULL) AND (next_attempt_at IS NULL) AND (failure_category IS NULL)) OR (((state)::text = 'running'::text) AND (attempt_count > 0) AND (started_at IS NOT NULL) AND (completed_at IS NULL) AND (next_attempt_at IS NULL) AND (failure_category IS NULL)) OR (((state)::text = 'retryable'::text) AND (attempt_count > 0) AND (started_at IS NOT NULL) AND (completed_at IS NULL) AND (next_attempt_at IS NOT NULL) AND (failure_category IS NOT NULL)) OR (((state)::text = ANY ((ARRAY['matched'::character varying, 'repaired'::character varying, 'ambiguous'::character varying])::text[])) AND (attempt_count > 0) AND (started_at IS NOT NULL) AND (completed_at IS NOT NULL) AND (next_attempt_at IS NULL) AND (failure_category IS NULL)) OR (((state)::text = ANY ((ARRAY['missing'::character varying, 'failed'::character varying])::text[])) AND (attempt_count > 0) AND (started_at IS NOT NULL) AND (completed_at IS NOT NULL) AND (next_attempt_at IS NULL) AND (failure_category IS NOT NULL)))),
    CONSTRAINT billing_reconciliations_provider_format CHECK (((provider)::text ~ '^[a-z][a-z0-9_]{1,31}$'::text)),
    CONSTRAINT billing_reconciliations_requester_shape CHECK (((((source)::text = 'scheduled'::text) AND (requested_by_user_id IS NULL)) OR (((source)::text = 'targeted'::text) AND (requested_by_user_id IS NOT NULL)))),
    CONSTRAINT billing_reconciliations_snapshot_bounded CHECK (((jsonb_typeof(provider_snapshot) = 'object'::text) AND (pg_column_size(provider_snapshot) <= 8192))),
    CONSTRAINT billing_reconciliations_source_allowlist CHECK (((source)::text = ANY ((ARRAY['scheduled'::character varying, 'targeted'::character varying])::text[]))),
    CONSTRAINT billing_reconciliations_state_allowlist CHECK (((state)::text = ANY ((ARRAY['queued'::character varying, 'running'::character varying, 'matched'::character varying, 'repaired'::character varying, 'ambiguous'::character varying, 'missing'::character varying, 'retryable'::character varying, 'failed'::character varying])::text[])))
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
    CONSTRAINT billing_changes_direction_allowlist CHECK (((direction)::text = ANY ((ARRAY['upgrade'::character varying, 'downgrade'::character varying])::text[]))),
    CONSTRAINT billing_changes_distinct_plan_versions CHECK ((from_plan_version_id <> target_plan_version_id)),
    CONSTRAINT billing_changes_interval_allowlist CHECK (((target_billing_interval)::text = ANY ((ARRAY['monthly'::character varying, 'annual'::character varying])::text[]))),
    CONSTRAINT billing_changes_lifecycle_shape CHECK (((effective_at >= requested_at) AND ((dispatch_enqueued_at IS NULL) OR (dispatch_enqueued_at >= requested_at)) AND ((((direction)::text = 'upgrade'::text) AND ((effective_policy)::text = 'immediate'::text) AND ((state)::text <> 'scheduled'::text)) OR (((direction)::text = 'downgrade'::text) AND ((effective_policy)::text = 'period_end'::text) AND ((state)::text <> 'pending'::text))) AND ((((state)::text = ANY ((ARRAY['pending'::character varying, 'scheduled'::character varying])::text[])) AND (submitted_at IS NULL) AND (applied_at IS NULL) AND (failed_at IS NULL) AND (failure_category IS NULL)) OR (((state)::text = 'submitted'::text) AND (submitted_at IS NOT NULL) AND (applied_at IS NULL) AND (failed_at IS NULL) AND (failure_category IS NULL)) OR (((state)::text = 'applied'::text) AND (submitted_at IS NOT NULL) AND (applied_at IS NOT NULL) AND (failed_at IS NULL) AND (failure_category IS NULL)) OR (((state)::text = 'failed'::text) AND (applied_at IS NULL) AND (failed_at IS NOT NULL) AND (failure_category IS NOT NULL)) OR (((state)::text = 'canceled'::text) AND (applied_at IS NULL) AND (failed_at IS NULL) AND (failure_category IS NULL))))),
    CONSTRAINT billing_changes_policy_allowlist CHECK (((effective_policy)::text = ANY ((ARRAY['immediate'::character varying, 'period_end'::character varying])::text[]))),
    CONSTRAINT billing_changes_state_allowlist CHECK (((state)::text = ANY ((ARRAY['pending'::character varying, 'scheduled'::character varying, 'submitted'::character varying, 'applied'::character varying, 'failed'::character varying, 'canceled'::character varying])::text[])))
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
    CONSTRAINT billing_support_grants_permission_allowlist CHECK (((permission)::text = ANY ((ARRAY['billing_support.read'::character varying, 'billing_support.manage'::character varying])::text[]))),
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
    CONSTRAINT domain_verification_attempts_failure_category_allowlist CHECK (((failure_category IS NULL) OR ((failure_category)::text = ANY ((ARRAY['proof_missing'::character varying, 'proof_mismatch'::character varying, 'provider_unavailable'::character varying, 'provider_unauthorized'::character varying, 'unsafe_destination'::character varying, 'malformed_response'::character varying, 'attempt_limit'::character varying, 'dns_nxdomain'::character varying, 'dns_no_record'::character varying, 'dns_propagating'::character varying, 'dns_timeout'::character varying, 'dns_transient_failure'::character varying, 'dns_multiple_records'::character varying, 'dns_response_limit'::character varying, 'dns_cname_limit'::character varying, 'dns_delegation_limit'::character varying])::text[])))),
    CONSTRAINT domain_verification_attempts_failure_shape CHECK (((((outcome)::text = 'verified'::text) AND (failure_category IS NULL)) OR (((outcome)::text = 'failed'::text) AND (failure_category IS NOT NULL)))),
    CONSTRAINT domain_verification_attempts_outcome CHECK (((sequence > 0) AND ((outcome)::text = ANY ((ARRAY['verified'::character varying, 'failed'::character varying])::text[]))))
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
    CONSTRAINT domain_verifications_attempt_shape CHECK (((attempt_count >= 0) AND (((attempt_count = 0) AND (attempted_at IS NULL)) OR ((attempt_count > 0) AND (attempted_at IS NOT NULL))))),
    CONSTRAINT domain_verifications_bounded_binding CHECK ((((char_length(expected_location) >= 1) AND (char_length(expected_location) <= 2048)) AND ((char_length(bound_origin) >= 8) AND (char_length(bound_origin) <= 2048)))),
    CONSTRAINT domain_verifications_digest_format CHECK (((challenge_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT domain_verifications_evidence_shape CHECK (((jsonb_typeof(evidence) = 'object'::text) AND (octet_length((evidence)::text) <= 4096))),
    CONSTRAINT domain_verifications_expiry_order CHECK ((expires_at > created_at)),
    CONSTRAINT domain_verifications_failure_category_allowlist CHECK (((failure_category IS NULL) OR ((failure_category)::text = ANY ((ARRAY['proof_missing'::character varying, 'proof_mismatch'::character varying, 'provider_unavailable'::character varying, 'provider_unauthorized'::character varying, 'unsafe_destination'::character varying, 'malformed_response'::character varying, 'attempt_limit'::character varying, 'dns_nxdomain'::character varying, 'dns_no_record'::character varying, 'dns_propagating'::character varying, 'dns_timeout'::character varying, 'dns_transient_failure'::character varying, 'dns_multiple_records'::character varying, 'dns_response_limit'::character varying, 'dns_cname_limit'::character varying, 'dns_delegation_limit'::character varying])::text[])))),
    CONSTRAINT domain_verifications_lifecycle CHECK (((((state)::text = 'pending'::text) AND (verified_at IS NULL) AND (failed_at IS NULL) AND (expired_at IS NULL) AND (revoked_at IS NULL) AND (failure_category IS NULL)) OR (((state)::text = 'verified'::text) AND (verified_at IS NOT NULL) AND (failed_at IS NULL) AND (expired_at IS NULL) AND (revoked_at IS NULL) AND (failure_category IS NULL)) OR (((state)::text = 'failed'::text) AND (verified_at IS NULL) AND (failed_at IS NOT NULL) AND (expired_at IS NULL) AND (revoked_at IS NULL) AND (failure_category IS NOT NULL)) OR (((state)::text = 'expired'::text) AND (failed_at IS NULL) AND (expired_at IS NOT NULL) AND (revoked_at IS NULL) AND (failure_category IS NULL)) OR (((state)::text = 'revoked'::text) AND (failed_at IS NULL) AND (expired_at IS NULL) AND (revoked_at IS NOT NULL) AND (failure_category IS NULL)))),
    CONSTRAINT domain_verifications_method_allowlist CHECK (((method)::text = ANY ((ARRAY['dns_txt'::character varying, 'html_file'::character varying, 'meta_tag'::character varying, 'search_console'::character varying])::text[]))),
    CONSTRAINT domain_verifications_state_allowlist CHECK (((state)::text = ANY ((ARRAY['pending'::character varying, 'verified'::character varying, 'failed'::character varying, 'expired'::character varying, 'revoked'::character varying])::text[])))
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
    CONSTRAINT entitlement_contexts_access_state_allowlist CHECK (((access_state)::text = ANY ((ARRAY['pending'::character varying, 'full'::character varying, 'grace'::character varying, 'read_only'::character varying, 'suspended'::character varying])::text[]))),
    CONSTRAINT entitlement_contexts_nonnegative_revision CHECK ((subscription_revision >= 0)),
    CONSTRAINT entitlement_contexts_subscription_status_allowlist CHECK (((subscription_status)::text = ANY ((ARRAY['pending'::character varying, 'incomplete'::character varying, 'trialing'::character varying, 'active'::character varying, 'past_due'::character varying, 'paused'::character varying, 'canceled'::character varying, 'expired'::character varying])::text[])))
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
    CONSTRAINT projects_authorization_scope_type CHECK (((authorization_scope_type)::text = 'Project'::text)),
    CONSTRAINT projects_description_bounded CHECK ((char_length(description) <= 2000)),
    CONSTRAINT projects_external_release_key_format CHECK (((external_release_key)::text ~ '^prj_[0-9a-f]{32}$'::text)),
    CONSTRAINT projects_lifecycle_consistency CHECK (((((status)::text = 'active'::text) AND (archived_at IS NULL) AND (deletion_requested_at IS NULL)) OR (((status)::text = 'archived'::text) AND (archived_at IS NOT NULL) AND (deletion_requested_at IS NULL)) OR (((status)::text = 'pending_deletion'::text) AND (archived_at IS NOT NULL) AND (deletion_requested_at IS NOT NULL) AND (deletion_requested_at >= archived_at)))),
    CONSTRAINT projects_locale_format CHECK (((default_locale)::text ~ '^[a-z]{2}(?:-[A-Z]{2})?$'::text)),
    CONSTRAINT projects_name_format CHECK ((((char_length((name)::text) >= 2) AND (char_length((name)::text) <= 160)) AND ((name)::text = btrim((name)::text)))),
    CONSTRAINT projects_slug_format CHECK (((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]{1,61}[a-z0-9])$'::text)),
    CONSTRAINT projects_time_zone_format CHECK ((((char_length((time_zone)::text) >= 1) AND (char_length((time_zone)::text) <= 64)) AND ((time_zone)::text = btrim((time_zone)::text))))
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
    CONSTRAINT properties_authorization_scope_types CHECK ((((authorization_scope_type)::text = 'Property'::text) AND ((authorization_project_scope_type)::text = 'Project'::text))),
    CONSTRAINT properties_configuration_version CHECK ((configuration_version = 1)),
    CONSTRAINT properties_display_name_format CHECK ((((char_length((display_name)::text) >= 2) AND (char_length((display_name)::text) <= 160)) AND ((display_name)::text = btrim((display_name)::text)))),
    CONSTRAINT properties_kind_allowlist CHECK (((kind)::text = ANY ((ARRAY['website'::character varying, 'web_application'::character varying, 'android_app'::character varying, 'ios_app'::character varying])::text[]))),
    CONSTRAINT properties_lifecycle_consistency CHECK (((((status)::text = 'active'::text) AND (archived_at IS NULL)) OR (((status)::text = 'archived'::text) AND (archived_at IS NOT NULL)))),
    CONSTRAINT properties_verification_status_allowlist CHECK (((verification_status)::text = ANY ((ARRAY['unverified'::character varying, 'pending'::character varying, 'verified'::character varying, 'failed'::character varying, 'expired'::character varying, 'revoked'::character varying])::text[]))),
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
    CONSTRAINT property_environments_canonical_origin CHECK ((((char_length(origin) >= 8) AND (char_length(origin) <= 2048)) AND (origin = ((((scheme)::text || '://'::text) || lower((host)::text)) ||
CASE
    WHEN ((((scheme)::text = 'http'::text) AND (port = 80)) OR (((scheme)::text = 'https'::text) AND (port = 443))) THEN ''::text
    ELSE (':'::text || (port)::text)
END)))),
    CONSTRAINT property_environments_display_name_format CHECK ((((char_length((display_name)::text) >= 2) AND (char_length((display_name)::text) <= 120)) AND ((display_name)::text = btrim((display_name)::text)))),
    CONSTRAINT property_environments_host_format CHECK ((((host)::text = lower((host)::text)) AND ((host)::text ~ '^[a-z0-9](?:[a-z0-9.-]{0,251}[a-z0-9])?$'::text))),
    CONSTRAINT property_environments_key_format CHECK ((((key)::text ~ '^[a-z][a-z0-9-]{1,62}$'::text) AND ((key)::text = lower((key)::text)))),
    CONSTRAINT property_environments_kind_allowlist CHECK (((kind)::text = ANY ((ARRAY['production'::character varying, 'staging'::character varying, 'development'::character varying, 'custom'::character varying])::text[]))),
    CONSTRAINT property_environments_lifecycle CHECK (((((status)::text = 'active'::text) AND (archived_at IS NULL)) OR (((status)::text = 'archived'::text) AND (archived_at IS NOT NULL)))),
    CONSTRAINT property_environments_primary_shape CHECK ((("primary" = false) OR (((kind)::text = 'production'::text) AND ((status)::text = 'active'::text)))),
    CONSTRAINT property_environments_property_type CHECK ((((property_kind)::text = ANY ((ARRAY['website'::character varying, 'web_application'::character varying])::text[])) AND (configuration_version = 1))),
    CONSTRAINT property_environments_transport CHECK ((((scheme)::text = ANY ((ARRAY['http'::character varying, 'https'::character varying])::text[])) AND ((port >= 1) AND (port <= 65535))))
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
    CONSTRAINT subscriptions_status_access_shape CHECK (((((status)::text = ANY ((ARRAY['pending'::character varying, 'incomplete'::character varying])::text[])) AND ((access_state)::text = 'pending'::text)) OR (((status)::text = ANY ((ARRAY['trialing'::character varying, 'active'::character varying])::text[])) AND ((access_state)::text = 'full'::text)) OR (((status)::text = 'past_due'::text) AND ((access_state)::text = ANY ((ARRAY['grace'::character varying, 'read_only'::character varying])::text[]))) OR (((status)::text = 'paused'::text) AND ((access_state)::text = ANY ((ARRAY['read_only'::character varying, 'suspended'::character varying])::text[]))) OR (((status)::text = 'canceled'::text) AND ((access_state)::text = ANY ((ARRAY['full'::character varying, 'read_only'::character varying])::text[]))) OR (((status)::text = 'expired'::text) AND ((access_state)::text = 'read_only'::text)))),
    CONSTRAINT subscriptions_status_allowlist CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'incomplete'::character varying, 'trialing'::character varying, 'active'::character varying, 'past_due'::character varying, 'paused'::character varying, 'canceled'::character varying, 'expired'::character varying])::text[]))),
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
    CONSTRAINT usage_quota_operations_digest_format CHECK ((((idempotency_key_digest)::text ~ '^[0-9a-f]{64}$'::text) AND ((request_checksum)::text ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT usage_quota_operations_kind_allowlist CHECK (((operation_kind)::text = ANY (ARRAY[('extend'::character varying)::text, ('finalize'::character varying)::text, ('release'::character varying)::text, ('expire'::character varying)::text]))),
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
    CONSTRAINT usage_quota_reservations_lifecycle_shape CHECK (((((state)::text = 'held'::text) AND (consumed_quantity = (0)::numeric) AND (released_quantity = (0)::numeric) AND (finalized_usage_event_id IS NULL) AND (finalized_at IS NULL) AND (released_at IS NULL) AND (expired_at IS NULL)) OR (((state)::text = 'finalized'::text) AND ((consumed_quantity + released_quantity) = held_quantity) AND (((consumed_quantity = (0)::numeric) AND (finalized_usage_event_id IS NULL)) OR ((consumed_quantity > (0)::numeric) AND (finalized_usage_event_id IS NOT NULL))) AND (finalized_at IS NOT NULL) AND (released_at IS NULL) AND (expired_at IS NULL)) OR (((state)::text = 'released'::text) AND (consumed_quantity = (0)::numeric) AND (released_quantity = held_quantity) AND (finalized_usage_event_id IS NULL) AND (finalized_at IS NULL) AND (released_at IS NOT NULL) AND (expired_at IS NULL)) OR (((state)::text = 'expired'::text) AND (consumed_quantity = (0)::numeric) AND (released_quantity = held_quantity) AND (finalized_usage_event_id IS NULL) AND (finalized_at IS NULL) AND (released_at IS NULL) AND (expired_at IS NOT NULL)))),
    CONSTRAINT usage_quota_reservations_limit_snapshot_shape CHECK (((((limit_kind)::text = 'unlimited'::text) AND (limit_quantity IS NULL) AND (entitlement_key IS NULL) AND ((entitlement_state)::text = 'unlimited'::text) AND (entitlement_definition_checksum IS NULL)) OR (((limit_kind)::text = 'capped'::text) AND (limit_quantity >= (0)::numeric) AND ((entitlement_key)::text ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'::text) AND ((entitlement_state)::text = ANY (ARRAY[('enabled'::character varying)::text, ('disabled'::character varying)::text])) AND ((entitlement_definition_checksum)::text ~ '^[0-9a-f]{64}$'::text)))),
    CONSTRAINT usage_quota_reservations_quantities_nonnegative CHECK (((requested_quantity > (0)::numeric) AND (held_quantity > (0)::numeric) AND (requested_quantity = held_quantity) AND (consumed_quantity >= (0)::numeric) AND (released_quantity >= (0)::numeric))),
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
    CONSTRAINT website_configs_canonical_origin CHECK ((((char_length(origin) >= 8) AND (char_length(origin) <= 2048)) AND (origin = ((((scheme)::text || '://'::text) || lower((host)::text)) ||
CASE
    WHEN ((((scheme)::text = 'http'::text) AND (port = 80)) OR (((scheme)::text = 'https'::text) AND (port = 443))) THEN ''::text
    ELSE (':'::text || (port)::text)
END)))),
    CONSTRAINT website_configs_host_format CHECK ((((host)::text = lower((host)::text)) AND ((host)::text ~ '^[a-z0-9](?:[a-z0-9.-]{0,251}[a-z0-9])?$'::text))),
    CONSTRAINT website_configs_transport CHECK ((((scheme)::text = ANY ((ARRAY['http'::character varying, 'https'::character varying])::text[])) AND ((port >= 1) AND (port <= 65535)))),
    CONSTRAINT website_configs_type_and_version CHECK ((((property_kind)::text = ANY ((ARRAY['website'::character varying, 'web_application'::character varying])::text[])) AND (configuration_version = 1)))
);


--
-- Name: authentication_rate_limit_buckets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authentication_rate_limit_buckets ALTER COLUMN id SET DEFAULT nextval('public.authentication_rate_limit_buckets_id_seq'::regclass);


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
-- Name: audit_events audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_pkey PRIMARY KEY (id);


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

CREATE UNIQUE INDEX index_billing_changes_on_active_subscription ON public.billing_subscription_changes USING btree (subscription_id) WHERE ((state)::text = ANY ((ARRAY['pending'::character varying, 'scheduled'::character varying, 'submitted'::character varying])::text[]));


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

CREATE UNIQUE INDEX index_billing_reconciliations_on_active_subscription ON public.billing_reconciliation_runs USING btree (subscription_id) WHERE ((state)::text = ANY ((ARRAY['queued'::character varying, 'running'::character varying, 'retryable'::character varying])::text[]));


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
-- Name: index_domain_verifications_on_challenge_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_domain_verifications_on_challenge_digest ON public.domain_verifications USING btree (challenge_digest);


--
-- Name: index_domain_verifications_on_current_environment; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_domain_verifications_on_current_environment ON public.domain_verifications USING btree (organization_id, environment_id) WHERE ((state)::text = ANY ((ARRAY['pending'::character varying, 'verified'::character varying])::text[]));


--
-- Name: index_domain_verifications_on_environment_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_domain_verifications_on_environment_state ON public.domain_verifications USING btree (organization_id, project_id, property_id, environment_id, state, created_at);


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
-- Name: billing_customers billing_customers_immutable_mapping; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER billing_customers_immutable_mapping BEFORE DELETE OR UPDATE ON public.billing_customers FOR EACH ROW EXECUTE FUNCTION public.enforce_billing_customer_mapping_immutability();


--
-- Name: domain_verification_attempts domain_verification_attempts_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER domain_verification_attempts_immutable BEFORE DELETE OR UPDATE ON public.domain_verification_attempts FOR EACH ROW EXECUTE FUNCTION public.prevent_domain_verification_attempt_mutation();


--
-- Name: domain_verifications domain_verifications_protect_binding; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER domain_verifications_protect_binding BEFORE UPDATE ON public.domain_verifications FOR EACH ROW EXECUTE FUNCTION public.protect_domain_verification_binding();


--
-- Name: domain_verifications domain_verifications_validate_origin; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER domain_verifications_validate_origin BEFORE INSERT ON public.domain_verifications FOR EACH ROW EXECUTE FUNCTION public.validate_domain_verification_origin();


--
-- Name: entitlement_definitions entitlement_definitions_stable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER entitlement_definitions_stable BEFORE DELETE OR UPDATE ON public.entitlement_definitions FOR EACH ROW EXECUTE FUNCTION public.enforce_entitlement_definition_stability();


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
-- Name: properties properties_protect_stable_identity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER properties_protect_stable_identity BEFORE UPDATE ON public.properties FOR EACH ROW EXECUTE FUNCTION public.protect_property_stable_identity();


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
-- Name: audit_events fk_audit_events_same_org_actor; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT fk_audit_events_same_org_actor FOREIGN KEY (organization_id, actor_membership_id) REFERENCES public.memberships(organization_id, id) ON DELETE RESTRICT;


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
-- Name: organization_ownerships fk_current_ownership_active_membership; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_ownerships
    ADD CONSTRAINT fk_current_ownership_active_membership FOREIGN KEY (organization_id, membership_id, membership_status) REFERENCES public.memberships(organization_id, id, status) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: domain_verifications fk_domain_verifications_tenant_environment; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_verifications
    ADD CONSTRAINT fk_domain_verifications_tenant_environment FOREIGN KEY (organization_id, project_id, property_id, environment_id) REFERENCES public.property_environments(organization_id, project_id, property_id, id) ON DELETE RESTRICT;


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
-- Name: projects fk_projects_same_org_authorization_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT fk_projects_same_org_authorization_scope FOREIGN KEY (organization_id, id, authorization_scope_type) REFERENCES public.authorization_scope_references(organization_id, id, scope_type) ON DELETE RESTRICT;


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
-- Name: billing_checkout_sessions fk_rails_9f7df1dbb1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_checkout_sessions
    ADD CONSTRAINT fk_rails_9f7df1dbb1 FOREIGN KEY (plan_version_id) REFERENCES public.plan_versions(id) ON DELETE RESTRICT;


--
-- Name: plan_versions fk_rails_ada72724a1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plan_versions
    ADD CONSTRAINT fk_rails_ada72724a1 FOREIGN KEY (plan_id) REFERENCES public.plans(id) ON DELETE RESTRICT;


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
