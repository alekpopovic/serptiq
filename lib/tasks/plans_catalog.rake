# frozen_string_literal: true

namespace :plans do
  namespace :catalog do
    desc "Validate the governed plan catalog without writing to the database"
    task validate: :environment do
      catalog = Plans::Public.validate_catalog
      puts "Plan catalog valid: #{catalog.definitions.length} plans, checksum #{catalog.checksum}"
    end

    desc "Synchronize governed plan versions (DRY_RUN=1 reports without writes)"
    task sync: :environment do
      dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", false))
      result = Plans::Public.sync_catalog(dry_run: dry_run)
      mode = result.dry_run? ? "dry-run" : "applied"
      puts "Plan catalog #{mode}: #{result.change_count} change(s), checksum #{result.checksum}"
      result.changes.each { |change| puts "- #{change}" }
    end
  end
end
