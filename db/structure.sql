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
-- Name: enforce_plan_version_immutability(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_plan_version_immutability() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
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
     (OLD.status IN ('retired', 'grandfathered') AND NEW.status <> OLD.status) THEN
    RAISE EXCEPTION 'invalid plan version lifecycle transition' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

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
    CONSTRAINT plan_catalog_grants_permission_allowlist CHECK (((permission)::text = ANY ((ARRAY['plan_catalog.read'::character varying, 'plan_catalog.publish'::character varying])::text[]))),
    CONSTRAINT plan_catalog_grants_revocation_order CHECK (((revoked_at IS NULL) OR (revoked_at >= granted_at)))
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
    CONSTRAINT plan_versions_lifecycle_shape CHECK (((((status)::text = 'draft'::text) AND (effective_at IS NULL) AND (published_at IS NULL) AND (retired_at IS NULL)) OR (((status)::text = 'published'::text) AND (effective_at IS NOT NULL) AND (published_at IS NOT NULL) AND (retired_at IS NULL)) OR (((status)::text = ANY ((ARRAY['retired'::character varying, 'grandfathered'::character varying])::text[])) AND (effective_at IS NOT NULL) AND (published_at IS NOT NULL) AND (retired_at IS NOT NULL)))),
    CONSTRAINT plan_versions_positive_version CHECK ((version > 0)),
    CONSTRAINT plan_versions_pricing_shape CHECK (((((pricing_kind)::text = 'fixed'::text) AND (monthly_price_cents IS NOT NULL) AND (monthly_price_cents >= 0) AND (annual_price_cents IS NOT NULL) AND (annual_price_cents >= 0)) OR (((pricing_kind)::text = 'custom'::text) AND (monthly_price_cents IS NULL) AND (annual_price_cents IS NULL)))),
    CONSTRAINT plan_versions_status_allowlist CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'published'::character varying, 'retired'::character varying, 'grandfathered'::character varying])::text[])))
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
    CONSTRAINT plans_key_allowlist CHECK (((key)::text = ANY ((ARRAY['free'::character varying, 'starter'::character varying, 'growth'::character varying, 'agency'::character varying, 'enterprise'::character varying])::text[])))
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
    CONSTRAINT subscriptions_interval_allowlist CHECK (((billing_interval)::text = ANY ((ARRAY['monthly'::character varying, 'annual'::character varying, 'custom'::character varying])::text[]))),
    CONSTRAINT subscriptions_lifecycle_shape CHECK (((((status)::text = 'active'::text) AND (ended_at IS NULL)) OR (((status)::text = 'inactive'::text) AND (ended_at IS NOT NULL)))),
    CONSTRAINT subscriptions_snapshot_price_shape CHECK (((((pricing_kind_snapshot)::text = 'fixed'::text) AND ((billing_interval)::text = ANY ((ARRAY['monthly'::character varying, 'annual'::character varying])::text[])) AND (price_cents_snapshot IS NOT NULL) AND (price_cents_snapshot >= 0)) OR (((pricing_kind_snapshot)::text = 'custom'::text) AND ((billing_interval)::text = 'custom'::text) AND (price_cents_snapshot IS NULL)))),
    CONSTRAINT subscriptions_status_allowlist CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])))
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
-- Name: authentication_rate_limit_buckets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authentication_rate_limit_buckets ALTER COLUMN id SET DEFAULT nextval('public.authentication_rate_limit_buckets_id_seq'::regclass);


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
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


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
-- Name: index_subscriptions_on_active_organization; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_subscriptions_on_active_organization ON public.subscriptions USING btree (organization_id) WHERE ((status)::text = 'active'::text);


--
-- Name: index_subscriptions_on_plan_version_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_plan_version_id_and_status ON public.subscriptions USING btree (plan_version_id, status);


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
-- Name: index_users_on_active_normalized_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_active_normalized_email ON public.users USING btree (lower((primary_email)::text)) WHERE ((primary_email IS NOT NULL) AND (deleted_at IS NULL));


--
-- Name: plan_versions plan_versions_immutable_snapshot; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER plan_versions_immutable_snapshot BEFORE DELETE OR UPDATE ON public.plan_versions FOR EACH ROW EXECUTE FUNCTION public.enforce_plan_version_immutability();


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
-- Name: organization_ownerships fk_current_ownership_active_membership; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_ownerships
    ADD CONSTRAINT fk_current_ownership_active_membership FOREIGN KEY (organization_id, membership_id, membership_status) REFERENCES public.memberships(organization_id, id, status) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


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
-- Name: role_permissions fk_rails_60126080bd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT fk_rails_60126080bd FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE RESTRICT;


--
-- Name: memberships fk_rails_64267aab58; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT fk_rails_64267aab58 FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: sessions fk_rails_850fa66024; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_850fa66024 FOREIGN KEY (rotated_from_id) REFERENCES public.sessions(id) ON DELETE RESTRICT;


--
-- Name: memberships fk_rails_99326fb65d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT fk_rails_99326fb65d FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: plan_versions fk_rails_ada72724a1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plan_versions
    ADD CONSTRAINT fk_rails_ada72724a1 FOREIGN KEY (plan_id) REFERENCES public.plans(id) ON DELETE RESTRICT;


--
-- Name: audit_events fk_rails_be0ed9e37f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT fk_rails_be0ed9e37f FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


--
-- Name: oauth_transactions fk_rails_cbf62b83df; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_transactions
    ADD CONSTRAINT fk_rails_cbf62b83df FOREIGN KEY (link_session_id) REFERENCES public.sessions(id) ON DELETE RESTRICT;


--
-- Name: role_assignments fk_rails_d5d049f535; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT fk_rails_d5d049f535 FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE RESTRICT;


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
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
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
