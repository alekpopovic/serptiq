# frozen_string_literal: true

namespace :authorization do
  namespace :catalog do
    desc "Validate the version-controlled permission and system-role catalog"
    task validate: :environment do
      catalog = Authorization::Public.validate_catalog
      puts "Authorization catalog valid: #{catalog.permissions.length} permissions, " \
        "#{catalog.roles.length} roles, sha256:#{catalog.checksum}"
    end

    desc "Idempotently synchronize permission and immutable system-role data"
    task sync: :environment do
      result = Authorization::Public.sync_catalog
      puts "Authorization catalog synchronized: #{result.permission_count} permissions, " \
        "#{result.role_count} roles, #{result.grant_count} grants, #{result.change_count} changes, " \
        "sha256:#{result.checksum}"
    end

    desc "Print the governed permission matrix for development and administrative review"
    task report: :environment do
      puts Authorization::Public.catalog_report
    end
  end
end
