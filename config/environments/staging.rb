# frozen_string_literal: true

# Staging deliberately uses the same secure runtime behavior as production.
# Searchops::Configuration still loads the dedicated `staging` section from
# config/searchops.yml and requires isolated staging origins and secrets.
require_relative "production"
