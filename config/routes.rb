Rails.application.routes.draw do
  root "public_pages#home"
  get "sign-in", to: "public_pages#sign_in", as: :sign_in
  post "sign-in", to: "public_pages#preview_sign_in"
  get "dashboard", to: "dashboard#index", as: :dashboard

  get "up", to: "operational_status#up", defaults: { format: :json }, as: :up
  get "ready", to: "operational_status#ready", defaults: { format: :json }, as: :ready
  get "version", to: "operational_status#version", defaults: { format: :json }, as: :version

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
