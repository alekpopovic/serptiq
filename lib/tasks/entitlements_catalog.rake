# frozen_string_literal: true

namespace :entitlements do
  namespace :catalog do
    desc "Validate typed definitions and all governed plan entitlement values"
    task validate: :environment do
      catalog = Entitlements::Public.validate_catalog
      puts "Entitlement catalog valid: #{catalog.definitions.length} definitions, checksum #{catalog.checksum}"
    end

    desc "Synchronize typed entitlement definitions and plan values (DRY_RUN=1 previews)"
    task sync: :environment do
      dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", false))
      result = Entitlements::Public.sync_catalog(dry_run: dry_run)
      mode = result.dry_run? ? "dry-run" : "applied"
      puts "Entitlement catalog #{mode}: #{result.change_count} change(s), checksum #{result.checksum}"
      result.changes.each { |change| puts "- #{change}" }
    end
  end
end
