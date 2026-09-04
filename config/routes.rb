Rails.application.routes.draw do
  root "public_pages#home"
  get "sign-in", to: "public_pages#sign_in", as: :sign_in
  get "invitations", to: "tenancy/invitation_entries#show", as: :invitation_entry
  post "auth/google", to: "identity/google_oauth#create", as: :google_oauth_authorization
  get "auth/google/callback", to: "identity/google_oauth#callback", as: :google_oauth_callback
  post "auth/github", to: "identity/github_oauth#create", as: :github_oauth_authorization
  get "auth/github/callback", to: "identity/github_oauth#callback", as: :github_oauth_callback
  delete "logout", to: "identity/sessions#destroy", as: :logout
  get "dashboard", to: "dashboard#index", as: :dashboard
  get "dashboard/admin/plans", to: "plans/catalog#index", as: :admin_plan_catalog
  post "dashboard/admin/plans/:plan_key/versions/:version/publish",
    to: "plans/catalog#publish",
    as: :publish_admin_plan_version
  patch "dashboard/admin/plans/:plan_key/versions/:version/retire",
    to: "plans/catalog#retire",
    as: :retire_admin_plan_version
  get "dashboard/organizations/new", to: "tenancy/organizations#new", as: :new_organization
  post "dashboard/organizations", to: "tenancy/organizations#create", as: :organizations
  get "dashboard/organizations/:organization_slug/switch",
    to: "tenancy/organization_switches#show",
    as: :switch_organization
  get "dashboard/organizations/:organization_slug/settings",
    to: "tenancy/organization_settings#show",
    as: :organization_settings
  patch "dashboard/organizations/:organization_slug/settings",
    to: "tenancy/organization_settings#update"
  get "dashboard/organizations/:organization_slug/audit",
    to: "auditing/audit_events#index",
    as: :organization_audit_events
  get "dashboard/organizations/:organization_slug/audit/export",
    to: "auditing/audit_events#export",
    as: :organization_audit_export
  get "dashboard/organizations/:organization_slug/entitlements",
    to: "entitlements/diagnostics#show",
    as: :organization_entitlements
  get "dashboard/organizations/:organization_slug/settings/ownership-transfer",
    to: "tenancy/ownership_transfers#show",
    as: :organization_ownership_transfer
  post "dashboard/organizations/:organization_slug/settings/ownership-transfer",
    to: "tenancy/ownership_transfers#create"
  get "dashboard/organizations/:organization_slug/members",
    to: "tenancy/members#index",
    as: :organization_members
  get "dashboard/organizations/:organization_slug/invitations",
    to: "tenancy/invitations#index",
    as: :organization_invitations
  get "dashboard/organizations/:organization_slug/invitations/new",
    to: "tenancy/invitations#new",
    as: :new_organization_invitation
  post "dashboard/organizations/:organization_slug/invitations",
    to: "tenancy/invitations#create"
  patch "dashboard/organizations/:organization_slug/invitations/:id/revoke",
    to: "tenancy/invitations#revoke",
    as: :revoke_organization_invitation
  post "dashboard/organizations/:organization_slug/invitations/:id/resend",
    to: "tenancy/invitations#resend",
    as: :resend_organization_invitation
  get "dashboard/organizations/:organization_slug/members/:id",
    to: "tenancy/members#show",
    as: :organization_member
  patch "dashboard/organizations/:organization_slug/members/:id/suspend",
    to: "tenancy/members#suspend",
    as: :suspend_organization_member
  patch "dashboard/organizations/:organization_slug/members/:id/reactivate",
    to: "tenancy/members#reactivate",
    as: :reactivate_organization_member
  patch "dashboard/organizations/:organization_slug/members/:id/remove",
    to: "tenancy/members#remove",
    as: :remove_organization_member
  get "dashboard/organizations/:organization_slug/teams",
    to: "tenancy/teams#index",
    as: :organization_teams
  get "dashboard/organizations/:organization_slug/teams/new",
    to: "tenancy/teams#new",
    as: :new_organization_team
  post "dashboard/organizations/:organization_slug/teams",
    to: "tenancy/teams#create"
  get "dashboard/organizations/:organization_slug/teams/:id",
    to: "tenancy/teams#show",
    as: :organization_team
  patch "dashboard/organizations/:organization_slug/teams/:id",
    to: "tenancy/teams#update"
  patch "dashboard/organizations/:organization_slug/teams/:id/archive",
    to: "tenancy/teams#archive",
    as: :archive_organization_team
  post "dashboard/organizations/:organization_slug/teams/:id/members",
    to: "tenancy/teams#add_member",
    as: :organization_team_members
  delete "dashboard/organizations/:organization_slug/teams/:id/members/:membership_id",
    to: "tenancy/teams#remove_member",
    as: :organization_team_member
  get "dashboard/organizations/:organization_slug", to: "dashboard#index", as: :organization_dashboard
  get "onboarding", to: "onboarding#show", as: :onboarding
  get "dashboard/invitations/review",
    to: "tenancy/invitation_acceptances#show",
    as: :invitation_review
  post "dashboard/invitations/accept",
    to: "tenancy/invitation_acceptances#create",
    as: :accept_invitation
  get "dashboard/account/profile", to: "identity/profiles#show", as: :account_profile
  patch "dashboard/account/profile", to: "identity/profiles#update"
  get "dashboard/account/security", to: "identity/account_security#show", as: :account_security
  get "dashboard/account/security/identities/:provider/link",
    to: "identity/account_security#confirm_link",
    as: :confirm_identity_link
  delete "dashboard/account/security/identities/:id",
    to: "identity/account_security#destroy",
    as: :provider_identity
  get "dashboard/account/sessions", to: "identity/sessions#index", as: :account_sessions
  delete "dashboard/account/sessions/others", to: "identity/sessions#revoke_others", as: :other_sessions
  delete "dashboard/account/sessions/:id", to: "identity/sessions#revoke", as: :account_session

  get "up", to: "operational_status#up", defaults: { format: :json }, as: :up
  get "ready", to: "operational_status#ready", defaults: { format: :json }, as: :ready
  get "version", to: "operational_status#version", defaults: { format: :json }, as: :version

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
