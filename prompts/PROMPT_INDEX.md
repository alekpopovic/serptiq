# Codex Prompt Index

Execute prompts in numeric order unless `prompt_tracker.rb next` identifies another eligible prompt. The dependency graph is authoritative.

| ID | Reasoning | Title | Dependencies | File |
|---:|---|---|---|---|
| 000 | medium | Repository reconnaissance and baseline snapshot | — | [`000_repository_reconnaissance_and_baseline_snapshot.md`](./000_repository_reconnaissance_and_baseline_snapshot.md) |
| 001 | high | Initialize Rails application and pin a compatible baseline | 000 | [`001_initialize_rails_application_and_pin_a_compatible_baseline.md`](./001_initialize_rails_application_and_pin_a_compatible_baseline.md) |
| 002 | high | Establish repository conventions and module boundaries | 001 | [`002_establish_repository_conventions_and_module_boundaries.md`](./002_establish_repository_conventions_and_module_boundaries.md) |
| 003 | high | Define environment, configuration and secrets contract | 002 | [`003_define_environment_configuration_and_secrets_contract.md`](./003_define_environment_configuration_and_secrets_contract.md) |
| 004 | medium | Integrate and verify the prompt execution tracker | 003 | [`004_integrate_and_verify_the_prompt_execution_tracker.md`](./004_integrate_and_verify_the_prompt_execution_tracker.md) |
| 005 | medium | Finalize ADR index and architecture guardrails | 004 | [`005_finalize_adr_index_and_architecture_guardrails.md`](./005_finalize_adr_index_and_architecture_guardrails.md) |
| 006 | high | Configure PostgreSQL databases and required extensions | 005 | [`006_configure_postgresql_databases_and_required_extensions.md`](./006_configure_postgresql_databases_and_required_extensions.md) |
| 007 | high | Configure Solid Queue, Solid Cache and Solid Cable topology | 006 | [`007_configure_solid_queue_solid_cache_and_solid_cable_topology.md`](./007_configure_solid_queue_solid_cache_and_solid_cable_topology.md) |
| 008 | medium | Build the Hotwire and Tailwind application shell | 007 | [`008_build_the_hotwire_and_tailwind_application_shell.md`](./008_build_the_hotwire_and_tailwind_application_shell.md) |
| 009 | medium | Add linting, static analysis and dependency security checks | 008 | [`009_add_linting_static_analysis_and_dependency_security_checks.md`](./009_add_linting_static_analysis_and_dependency_security_checks.md) |
| 010 | high | Establish the Minitest and system-test foundation | 009 | [`010_establish_the_minitest_and_system_test_foundation.md`](./010_establish_the_minitest_and_system_test_foundation.md) |
| 011 | high | Create GitHub Actions continuous integration | 010 | [`011_create_github_actions_continuous_integration.md`](./011_create_github_actions_continuous_integration.md) |
| 012 | high | Implement structured events and error taxonomy | 011 | [`012_implement_structured_events_and_error_taxonomy.md`](./012_implement_structured_events_and_error_taxonomy.md) |
| 013 | medium | Implement health, readiness and version endpoints | 012 | [`013_implement_health_readiness_and_version_endpoints.md`](./013_implement_health_readiness_and_version_endpoints.md) |
| 014 | high | Create native authentication and session foundations | 013 | [`014_create_native_authentication_and_session_foundations.md`](./014_create_native_authentication_and_session_foundations.md) |
| 015 | high | Model users, identities, sessions and OAuth transactions | 014 | [`015_model_users_identities_sessions_and_oauth_transactions.md`](./015_model_users_identities_sessions_and_oauth_transactions.md) |
| 016 | high | Define the OAuth/OIDC provider adapter architecture | 015 | [`016_define_the_oauth_oidc_provider_adapter_architecture.md`](./016_define_the_oauth_oidc_provider_adapter_architecture.md) |
| 017 | xhigh | Implement Google OIDC authorization start with PKCE, state and nonce | 016 | [`017_implement_google_oidc_authorization_start_with_pkce_state_and_nonce.md`](./017_implement_google_oidc_authorization_start_with_pkce_state_and_nonce.md) |
| 018 | xhigh | Implement Google OIDC callback and token validation | 017 | [`018_implement_google_oidc_callback_and_token_validation.md`](./018_implement_google_oidc_callback_and_token_validation.md) |
| 019 | high | Implement the GitHub OAuth sign-in adapter | 018 | [`019_implement_the_github_oauth_sign_in_adapter.md`](./019_implement_the_github_oauth_sign_in_adapter.md) |
| 020 | xhigh | Implement identity linking and collision prevention | 019 | [`020_implement_identity_linking_and_collision_prevention.md`](./020_implement_identity_linking_and_collision_prevention.md) |
| 021 | high | Harden session rotation, revocation and device management | 020 | [`021_harden_session_rotation_revocation_and_device_management.md`](./021_harden_session_rotation_revocation_and_device_management.md) |
| 022 | medium | Build authentication and first-run onboarding UI | 021 | [`022_build_authentication_and_first_run_onboarding_ui.md`](./022_build_authentication_and_first_run_onboarding_ui.md) |
| 023 | xhigh | Add authentication rate limits and security regression suite | 022 | [`023_add_authentication_rate_limits_and_security_regression_suite.md`](./023_add_authentication_rate_limits_and_security_regression_suite.md) |
| 024 | xhigh | Implement organizations, slugs and current tenant context | 023 | [`024_implement_organizations_slugs_and_current_tenant_context.md`](./024_implement_organizations_slugs_and_current_tenant_context.md) |
| 025 | medium | Build organization creation, settings and switcher flows | 024 | [`025_build_organization_creation_settings_and_switcher_flows.md`](./025_build_organization_creation_settings_and_switcher_flows.md) |
| 026 | high | Implement membership lifecycle | 025 | [`026_implement_membership_lifecycle.md`](./026_implement_membership_lifecycle.md) |
| 027 | high | Implement teams and team memberships | 026 | [`027_implement_teams_and_team_memberships.md`](./027_implement_teams_and_team_memberships.md) |
| 028 | xhigh | Implement secure organization invitations | 027 | [`028_implement_secure_organization_invitations.md`](./028_implement_secure_organization_invitations.md) |
| 029 | high | Seed permissions and immutable system roles | 028 | [`029_seed_permissions_and_immutable_system_roles.md`](./029_seed_permissions_and_immutable_system_roles.md) |
| 030 | xhigh | Implement scoped role assignments | 029 | [`030_implement_scoped_role_assignments.md`](./030_implement_scoped_role_assignments.md) |
| 031 | xhigh | Implement the authorization decision service | 030 | [`031_implement_the_authorization_decision_service.md`](./031_implement_the_authorization_decision_service.md) |
| 032 | high | Enforce authorization in controllers, views, jobs and API boundaries | 031 | [`032_enforce_authorization_in_controllers_views_jobs_and_api_boundaries.md`](./032_enforce_authorization_in_controllers_views_jobs_and_api_boundaries.md) |
| 033 | xhigh | Implement organization ownership transfer with recent authentication | 032 | [`033_implement_organization_ownership_transfer_with_recent_authentication.md`](./033_implement_organization_ownership_transfer_with_recent_authentication.md) |
| 034 | xhigh | Enforce last-owner and member-removal invariants | 033 | [`034_enforce_last_owner_and_member_removal_invariants.md`](./034_enforce_last_owner_and_member_removal_invariants.md) |
| 035 | high | Complete tenancy and RBAC audit coverage | 034 | [`035_complete_tenancy_and_rbac_audit_coverage.md`](./035_complete_tenancy_and_rbac_audit_coverage.md) |
| 036 | high | Implement plans and immutable plan versions | 035 | [`036_implement_plans_and_immutable_plan_versions.md`](./036_implement_plans_and_immutable_plan_versions.md) |
| 037 | xhigh | Implement plan catalog publishing and grandfathering | 036 | [`037_implement_plan_catalog_publishing_and_grandfathering.md`](./037_implement_plan_catalog_publishing_and_grandfathering.md) |
| 038 | xhigh | Implement typed entitlement definitions and resolution | 037 | [`038_implement_typed_entitlement_definitions_and_resolution.md`](./038_implement_typed_entitlement_definitions_and_resolution.md) |
| 039 | xhigh | Implement immutable usage ledger and metering windows | 038 | [`039_implement_immutable_usage_ledger_and_metering_windows.md`](./039_implement_immutable_usage_ledger_and_metering_windows.md) |
| 040 | xhigh | Implement atomic quota reservations and finalization | 039 | [`040_implement_atomic_quota_reservations_and_finalization.md`](./040_implement_atomic_quota_reservations_and_finalization.md) |
| 041 | medium | Build pricing, plan comparison and usage UI | 040 | [`041_build_pricing_plan_comparison_and_usage_ui.md`](./041_build_pricing_plan_comparison_and_usage_ui.md) |
| 042 | xhigh | Create the unified permission-entitlement-quota access boundary | 041 | [`042_create_the_unified_permission_entitlement_quota_access_boundary.md`](./042_create_the_unified_permission_entitlement_quota_access_boundary.md) |
| 043 | high | Define the provider-neutral billing contract | 042 | [`043_define_the_provider_neutral_billing_contract.md`](./043_define_the_provider_neutral_billing_contract.md) |
| 044 | high | Implement the Lemon Squeezy billing client | 043 | [`044_implement_the_lemon_squeezy_billing_client.md`](./044_implement_the_lemon_squeezy_billing_client.md) |
| 045 | high | Implement hosted checkout and customer portal flows | 044 | [`045_implement_hosted_checkout_and_customer_portal_flows.md`](./045_implement_hosted_checkout_and_customer_portal_flows.md) |
| 046 | xhigh | Implement billing webhook ingress, signature verification and durable storage | 045 | [`046_implement_billing_webhook_ingress_signature_verification_and_durable_storage.md`](./046_implement_billing_webhook_ingress_signature_verification_and_durable_storage.md) |
| 047 | xhigh | Implement idempotent asynchronous billing event projection | 046 | [`047_implement_idempotent_asynchronous_billing_event_projection.md`](./047_implement_idempotent_asynchronous_billing_event_projection.md) |
| 048 | xhigh | Implement subscription lifecycle and access policy | 047 | [`048_implement_subscription_lifecycle_and_access_policy.md`](./048_implement_subscription_lifecycle_and_access_policy.md) |
| 049 | xhigh | Add billing reconciliation and support operations | 048 | [`049_add_billing_reconciliation_and_support_operations.md`](./049_add_billing_reconciliation_and_support_operations.md) |
| 050 | high | Implement project aggregate and lifecycle | 049 | [`050_implement_project_aggregate_and_lifecycle.md`](./050_implement_project_aggregate_and_lifecycle.md) |
| 051 | high | Implement polymorphic property model and typed configurations | 050 | [`051_implement_polymorphic_property_model_and_typed_configurations.md`](./051_implement_polymorphic_property_model_and_typed_configurations.md) |
| 052 | xhigh | Implement environments and canonical URL origin normalization | 051 | [`052_implement_environments_and_canonical_url_origin_normalization.md`](./052_implement_environments_and_canonical_url_origin_normalization.md) |
| 053 | high | Create the domain verification aggregate and lifecycle | 052 | [`053_create_the_domain_verification_aggregate_and_lifecycle.md`](./053_create_the_domain_verification_aggregate_and_lifecycle.md) |
| 054 | xhigh | Implement DNS TXT domain verification | 053 | [`054_implement_dns_txt_domain_verification.md`](./054_implement_dns_txt_domain_verification.md) |
| 055 | xhigh | Implement HTML file and meta-tag verification | 054 | [`055_implement_html_file_and_meta_tag_verification.md`](./055_implement_html_file_and_meta_tag_verification.md) |
| 056 | high | Implement Search Console ownership verification | 055 | [`056_implement_search_console_ownership_verification.md`](./056_implement_search_console_ownership_verification.md) |
| 057 | high | Build the guided project and property onboarding wizard | 056 | [`057_build_the_guided_project_and_property_onboarding_wizard.md`](./057_build_the_guided_project_and_property_onboarding_wizard.md) |
| 058 | xhigh | Implement crawl settings and policy configuration | 057 | [`058_implement_crawl_settings_and_policy_configuration.md`](./058_implement_crawl_settings_and_policy_configuration.md) |
| 059 | xhigh | Complete project- and property-scoped access enforcement | 058 | [`059_complete_project_and_property_scoped_access_enforcement.md`](./059_complete_project_and_property_scoped_access_enforcement.md) |
| 060 | xhigh | Implement archive, deletion and retention workflows | 059 | [`060_implement_archive_deletion_and_retention_workflows.md`](./060_implement_archive_deletion_and_retention_workflows.md) |
| 061 | medium | Build project dashboard and baseline readiness views | 060 | [`061_build_project_dashboard_and_baseline_readiness_views.md`](./061_build_project_dashboard_and_baseline_readiness_views.md) |
| 062 | xhigh | Implement the scan aggregate and state machine | 061 | [`062_implement_the_scan_aggregate_and_state_machine.md`](./062_implement_the_scan_aggregate_and_state_machine.md) |
| 063 | xhigh | Implement scan admission, idempotency and preflight | 062 | [`063_implement_scan_admission_idempotency_and_preflight.md`](./063_implement_scan_admission_idempotency_and_preflight.md) |
| 064 | xhigh | Implement the PostgreSQL crawl frontier with leasing | 063 | [`064_implement_the_postgresql_crawl_frontier_with_leasing.md`](./064_implement_the_postgresql_crawl_frontier_with_leasing.md) |
| 065 | xhigh | Implement canonical URL normalization and scope policy | 064 | [`065_implement_canonical_url_normalization_and_scope_policy.md`](./065_implement_canonical_url_normalization_and_scope_policy.md) |
| 066 | xhigh | Implement RFC 9309 robots parsing and policy | 065 | [`066_implement_rfc_9309_robots_parsing_and_policy.md`](./066_implement_rfc_9309_robots_parsing_and_policy.md) |
| 067 | xhigh | Implement sitemap discovery and bounded XML parsing | 066 | [`067_implement_sitemap_discovery_and_bounded_xml_parsing.md`](./067_implement_sitemap_discovery_and_bounded_xml_parsing.md) |
| 068 | xhigh | Implement the SSRF-safe destination resolver and connection policy | 067 | [`068_implement_the_ssrf_safe_destination_resolver_and_connection_policy.md`](./068_implement_the_ssrf_safe_destination_resolver_and_connection_policy.md) |
| 069 | xhigh | Implement the bounded HTTP fetcher and redirect handling | 068 | [`069_implement_the_bounded_http_fetcher_and_redirect_handling.md`](./069_implement_the_bounded_http_fetcher_and_redirect_handling.md) |
| 070 | xhigh | Implement private artifact storage and lifecycle | 069 | [`070_implement_private_artifact_storage_and_lifecycle.md`](./070_implement_private_artifact_storage_and_lifecycle.md) |
| 071 | xhigh | Implement host politeness, concurrency and rate controls | 070 | [`071_implement_host_politeness_concurrency_and_rate_controls.md`](./071_implement_host_politeness_concurrency_and_rate_controls.md) |
| 072 | xhigh | Integrate weighted credit reservation with scan execution | 071 | [`072_integrate_weighted_credit_reservation_with_scan_execution.md`](./072_integrate_weighted_credit_reservation_with_scan_execution.md) |
| 073 | xhigh | Implement static crawl orchestration | 072 | [`073_implement_static_crawl_orchestration.md`](./073_implement_static_crawl_orchestration.md) |
| 074 | high | Implement HTML extraction and internal link graph | 073 | [`074_implement_html_extraction_and_internal_link_graph.md`](./074_implement_html_extraction_and_internal_link_graph.md) |
| 075 | xhigh | Implement dedicated Chromium/Ferrum render workers | 074 | [`075_implement_dedicated_chromium_ferrum_render_workers.md`](./075_implement_dedicated_chromium_ferrum_render_workers.md) |
| 076 | xhigh | Harden browser network interception and sandbox limits | 075 | [`076_harden_browser_network_interception_and_sandbox_limits.md`](./076_harden_browser_network_interception_and_sandbox_limits.md) |
| 077 | xhigh | Implement scan cancellation, recovery and targeted rescan | 076 | [`077_implement_scan_cancellation_recovery_and_targeted_rescan.md`](./077_implement_scan_cancellation_recovery_and_targeted_rescan.md) |
| 078 | xhigh | Implement the versioned SEO rule registry and result contract | 077 | [`078_implement_the_versioned_seo_rule_registry_and_result_contract.md`](./078_implement_the_versioned_seo_rule_registry_and_result_contract.md) |
| 079 | high | Implement HTTP status and redirect rules | 078 | [`079_implement_http_status_and_redirect_rules.md`](./079_implement_http_status_and_redirect_rules.md) |
| 080 | xhigh | Implement robots, indexability and sitemap rules | 079 | [`080_implement_robots_indexability_and_sitemap_rules.md`](./080_implement_robots_indexability_and_sitemap_rules.md) |
| 081 | xhigh | Implement canonical and hreflang rules | 080 | [`081_implement_canonical_and_hreflang_rules.md`](./081_implement_canonical_and_hreflang_rules.md) |
| 082 | high | Implement metadata, content-structure and mobile rules | 081 | [`082_implement_metadata_content_structure_and_mobile_rules.md`](./082_implement_metadata_content_structure_and_mobile_rules.md) |
| 083 | high | Implement internal link and image rules | 082 | [`083_implement_internal_link_and_image_rules.md`](./083_implement_internal_link_and_image_rules.md) |
| 084 | xhigh | Implement structured-data extraction and validation rules | 083 | [`084_implement_structured_data_extraction_and_validation_rules.md`](./084_implement_structured_data_extraction_and_validation_rules.md) |
| 085 | xhigh | Implement source-versus-rendered parity rules | 084 | [`085_implement_source_versus_rendered_parity_rules.md`](./085_implement_source_versus_rendered_parity_rules.md) |
| 086 | high | Implement AI crawler policy matrix | 085 | [`086_implement_ai_crawler_policy_matrix.md`](./086_implement_ai_crawler_policy_matrix.md) |
| 087 | xhigh | Implement finding persistence, deduplication and occurrences | 086 | [`087_implement_finding_persistence_deduplication_and_occurrences.md`](./087_implement_finding_persistence_deduplication_and_occurrences.md) |
| 088 | xhigh | Implement severity, confidence and priority scoring | 087 | [`088_implement_severity_confidence_and_priority_scoring.md`](./088_implement_severity_confidence_and_priority_scoring.md) |
| 089 | xhigh | Implement issue workflow, assignment, comments and verified resolution | 088 | [`089_implement_issue_workflow_assignment_comments_and_verified_resolution.md`](./089_implement_issue_workflow_assignment_comments_and_verified_resolution.md) |
| 090 | xhigh | Implement scan baselines, diffs and regressions | 089 | [`090_implement_scan_baselines_diffs_and_regressions.md`](./090_implement_scan_baselines_diffs_and_regressions.md) |
| 091 | xhigh | Implement encrypted integration credentials and token refresh | 090 | [`091_implement_encrypted_integration_credentials_and_token_refresh.md`](./091_implement_encrypted_integration_credentials_and_token_refresh.md) |
| 092 | xhigh | Implement Search Console connection and property mapping | 091 | [`092_implement_search_console_connection_and_property_mapping.md`](./092_implement_search_console_connection_and_property_mapping.md) |
| 093 | xhigh | Implement Search Analytics import and read models | 092 | [`093_implement_search_analytics_import_and_read_models.md`](./093_implement_search_analytics_import_and_read_models.md) |
| 094 | xhigh | Implement URL Inspection import | 093 | [`094_implement_url_inspection_import.md`](./094_implement_url_inspection_import.md) |
| 095 | high | Implement CrUX field-data client and history | 094 | [`095_implement_crux_field_data_client_and_history.md`](./095_implement_crux_field_data_client_and_history.md) |
| 096 | xhigh | Implement isolated Lighthouse runner | 095 | [`096_implement_isolated_lighthouse_runner.md`](./096_implement_isolated_lighthouse_runner.md) |
| 097 | high | Build the field, lab and crawl performance read model | 096 | [`097_build_the_field_lab_and_crawl_performance_read_model.md`](./097_build_the_field_lab_and_crawl_performance_read_model.md) |
| 098 | xhigh | Implement traffic-aware finding prioritization | 097 | [`098_implement_traffic_aware_finding_prioritization.md`](./098_implement_traffic_aware_finding_prioritization.md) |
| 099 | xhigh | Implement scheduled scans and dynamic recurring tasks | 098 | [`099_implement_scheduled_scans_and_dynamic_recurring_tasks.md`](./099_implement_scheduled_scans_and_dynamic_recurring_tasks.md) |
| 100 | xhigh | Implement Android property and Digital Asset Links validation | 099 | [`100_implement_android_property_and_digital_asset_links_validation.md`](./100_implement_android_property_and_digital_asset_links_validation.md) |
| 101 | xhigh | Implement Android manifest import and App Links analysis | 100 | [`101_implement_android_manifest_import_and_app_links_analysis.md`](./101_implement_android_manifest_import_and_app_links_analysis.md) |
| 102 | xhigh | Implement iOS AASA and Associated Domains validation | 101 | [`102_implement_ios_aasa_and_associated_domains_validation.md`](./102_implement_ios_aasa_and_associated_domains_validation.md) |
| 103 | high | Implement App Store listing snapshots and audit | 102 | [`103_implement_app_store_listing_snapshots_and_audit.md`](./103_implement_app_store_listing_snapshots_and_audit.md) |
| 104 | high | Implement Google Play listing snapshots and audit | 103 | [`104_implement_google_play_listing_snapshots_and_audit.md`](./104_implement_google_play_listing_snapshots_and_audit.md) |
| 105 | xhigh | Implement the web-to-app route map | 104 | [`105_implement_the_web_to_app_route_map.md`](./105_implement_the_web_to_app_route_map.md) |
| 106 | xhigh | Implement releases and authenticated incoming deployment webhooks | 105 | [`106_implement_releases_and_authenticated_incoming_deployment_webhooks.md`](./106_implement_releases_and_authenticated_incoming_deployment_webhooks.md) |
| 107 | xhigh | Implement release guard policies and status publishing | 106 | [`107_implement_release_guard_policies_and_status_publishing.md`](./107_implement_release_guard_policies_and_status_publishing.md) |
| 108 | xhigh | Implement immutable report snapshots and export | 107 | [`108_implement_immutable_report_snapshots_and_export.md`](./108_implement_immutable_report_snapshots_and_export.md) |
| 109 | high | Implement scheduled reports and delivery | 108 | [`109_implement_scheduled_reports_and_delivery.md`](./109_implement_scheduled_reports_and_delivery.md) |
| 110 | high | Implement email, Slack and in-app notifications | 109 | [`110_implement_email_slack_and_in_app_notifications.md`](./110_implement_email_slack_and_in_app_notifications.md) |
| 111 | xhigh | Implement API keys, public API, outgoing webhooks and IndexNow | 110 | [`111_implement_api_keys_public_api_outgoing_webhooks_and_indexnow.md`](./111_implement_api_keys_public_api_outgoing_webhooks_and_indexnow.md) |
| 112 | xhigh | Implement safe administration and operations dashboards | 111 | [`112_implement_safe_administration_and_operations_dashboards.md`](./112_implement_safe_administration_and_operations_dashboards.md) |
| 113 | xhigh | Implement audit retention, privacy export and deletion workflows | 112 | [`113_implement_audit_retention_privacy_export_and_deletion_workflows.md`](./113_implement_audit_retention_privacy_export_and_deletion_workflows.md) |
| 114 | xhigh | Complete observability, metrics, tracing and alert definitions | 113 | [`114_complete_observability_metrics_tracing_and_alert_definitions.md`](./114_complete_observability_metrics_tracing_and_alert_definitions.md) |
| 115 | xhigh | Optimize indexes, query plans, partitioning and retention | 114 | [`115_optimize_indexes_query_plans_partitioning_and_retention.md`](./115_optimize_indexes_query_plans_partitioning_and_retention.md) |
| 116 | xhigh | Build hardened production images and process topology | 115 | [`116_build_hardened_production_images_and_process_topology.md`](./116_build_hardened_production_images_and_process_topology.md) |
| 117 | xhigh | Configure staging and production deployment with Kamal | 116 | [`117_configure_staging_and_production_deployment_with_kamal.md`](./117_configure_staging_and_production_deployment_with_kamal.md) |
| 118 | xhigh | Execute production security, backup and disaster-recovery hardening | 117 | [`118_execute_production_security_backup_and_disaster_recovery_hardening.md`](./118_execute_production_security_backup_and_disaster_recovery_hardening.md) |
| 119 | xhigh | Run final acceptance, pilot readiness and production MVP release review | 118 | [`119_run_final_acceptance_pilot_readiness_and_production_mvp_release_review.md`](./119_run_final_acceptance_pilot_readiness_and_production_mvp_release_review.md) |
