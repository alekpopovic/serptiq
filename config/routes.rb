Rails.application.routes.draw do
  root "public_pages#home"
  get "sign-in", to: "public_pages#sign_in", as: :sign_in
  post "auth/google", to: "identity/google_oauth#create", as: :google_oauth_authorization
  get "auth/google/callback", to: "identity/google_oauth#callback", as: :google_oauth_callback
  post "auth/github", to: "identity/github_oauth#create", as: :github_oauth_authorization
  get "auth/github/callback", to: "identity/github_oauth#callback", as: :github_oauth_callback
  delete "logout", to: "identity/sessions#destroy", as: :logout
  get "dashboard", to: "dashboard#index", as: :dashboard
  get "dashboard/account/security", to: "identity/account_security#show", as: :account_security
  get "dashboard/account/security/identities/:provider/link",
    to: "identity/account_security#confirm_link",
    as: :confirm_identity_link
  delete "dashboard/account/security/identities/:id",
    to: "identity/account_security#destroy",
    as: :provider_identity

  get "up", to: "operational_status#up", defaults: { format: :json }, as: :up
  get "ready", to: "operational_status#ready", defaults: { format: :json }, as: :ready
  get "version", to: "operational_status#version", defaults: { format: :json }, as: :version

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
