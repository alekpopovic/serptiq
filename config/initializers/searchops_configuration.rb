# frozen_string_literal: true

require Rails.root.join("config/searchops/configuration")
require Rails.root.join("config/searchops/database_configuration_validator")
require Rails.root.join("app/domains/shared/redaction")

settings = Searchops::Configuration.load(
  environment: Rails.env,
  env: ENV,
  credentials: Rails.application.credentials,
  path: Rails.root.join("config/searchops.yml")
)

Rails.application.config.x.searchops = settings
Rails.application.config.x.redaction = Shared::Redaction.new
Searchops::DatabaseConfigurationValidator.new(environment: Rails.env).validate!

origin = settings.fetch(:application_origin)
Rails.application.config.action_mailer.default_url_options = {
  protocol: origin.scheme,
  host: origin.host,
  port: origin.port
}.compact

if Searchops::Configuration::PROTECTED_ENVIRONMENTS.include?(Rails.env)
  Rails.application.config.force_ssl = true
  Rails.application.config.hosts << origin.host
  Rails.application.config.active_record.encryption.primary_key = settings.secret(:encryption_primary_keys)
  Rails.application.config.active_record.encryption.deterministic_key = settings.secret(:encryption_deterministic_key)
  Rails.application.config.active_record.encryption.key_derivation_salt = settings.secret(:encryption_key_derivation_salt)
end
