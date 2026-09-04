# frozen_string_literal: true

namespace :usage do
  namespace :catalog do
    desc "Validate the immutable usage meter and weighted-rate catalog"
    task validate: :environment do
      catalog = Usage::Public.validate_catalog
      rate_count = catalog.meters.sum { |meter| meter.rates.length }
      puts "Usage catalog valid: #{catalog.meters.length} meters, #{rate_count} rates, " \
        "sha256:#{catalog.checksum}"
    end

    desc "Idempotently synchronize usage meters and effective weighted rates"
    task sync: :environment do
      dry_run = ActiveModel::Type::Boolean.new.cast(ENV["DRY_RUN"])
      result = Usage::Public.sync_catalog(dry_run: dry_run)
      action = result.dry_run? ? "previewed" : "synchronized"
      puts "Usage catalog #{action}: #{result.meter_count} meters, #{result.rate_count} rates, " \
        "#{result.change_count} changes, sha256:#{result.checksum}"
      result.changes.each { |change| puts "- #{change}" }
    end
  end
end
