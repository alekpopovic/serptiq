# Be sure to restart your server when you modify this file.

require Rails.root.join("app/domains/shared/redaction")

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += Shared::Redaction::FILTERS + [
  :email,
  :crypt,
  :salt,
  :certificate,
  :ssn
]
