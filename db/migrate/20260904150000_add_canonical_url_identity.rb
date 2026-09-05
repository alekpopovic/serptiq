# frozen_string_literal: true

class AddCanonicalUrlIdentity < ActiveRecord::Migration[8.1]
  BATCH_SIZE = 10_000

  def up
    add_column :crawl_urls, :fetch_url, :text
    add_check_constraint :crawl_urls,
      "fetch_url IS NOT NULL AND octet_length(fetch_url) BETWEEN 1 AND 8192",
      name: "crawl_urls_fetch_url_shape", validate: false
    backfill_fetch_urls
    validate_check_constraint :crawl_urls, name: "crawl_urls_fetch_url_shape"
    change_column_null :crawl_urls, :fetch_url, false

    add_column :crawl_policy_versions, :query_parameter_allowlist, :text,
      array: true, null: false, default: []
    add_column :crawl_policy_versions, :query_parameter_denylist, :text,
      array: true, null: false, default: []
    add_check_constraint :crawl_policy_versions,
      "cardinality(query_parameter_allowlist) <= 50 " \
        "AND cardinality(query_parameter_denylist) <= 50 " \
        "AND array_position(query_parameter_allowlist, NULL) IS NULL " \
        "AND array_position(query_parameter_denylist, NULL) IS NULL " \
        "AND octet_length(array_to_string(query_parameter_allowlist, '')) <= 6400 " \
        "AND octet_length(array_to_string(query_parameter_denylist, '')) <= 6400",
      name: "crawl_policy_versions_query_parameter_lists"

    replace_frontier_guard(include_fetch_url: true)
  end

  def down
    replace_frontier_guard(include_fetch_url: false)
    remove_check_constraint :crawl_policy_versions,
      name: "crawl_policy_versions_query_parameter_lists"
    remove_column :crawl_policy_versions, :query_parameter_denylist
    remove_column :crawl_policy_versions, :query_parameter_allowlist
    remove_check_constraint :crawl_urls, name: "crawl_urls_fetch_url_shape"
    remove_column :crawl_urls, :fetch_url
  end

  private

  def backfill_fetch_urls
    loop do
      updated = execute(<<~SQL.squish).cmd_tuples
        UPDATE crawl_urls
        SET fetch_url = normalized_url
        WHERE id IN (
          SELECT id FROM crawl_urls WHERE fetch_url IS NULL ORDER BY id LIMIT #{BATCH_SIZE}
        )
      SQL
      break if updated.zero?
    end
  end

  def replace_frontier_guard(include_fetch_url:)
    fetch_url_clause = include_fetch_url ? "OR NEW.fetch_url IS DISTINCT FROM OLD.fetch_url" : ""
    execute <<~SQL
      CREATE OR REPLACE FUNCTION protect_crawl_url_identity() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          IF resource_deletion_stage_authorized(
            OLD.organization_id, OLD.project_id, OLD.property_id, 'scans_and_findings'
          ) THEN
            RETURN OLD;
          END IF;
          RAISE EXCEPTION 'crawl URL deletion requires an active lifecycle workflow';
        END IF;

        IF NEW.organization_id IS DISTINCT FROM OLD.organization_id
          OR NEW.project_id IS DISTINCT FROM OLD.project_id
          OR NEW.property_id IS DISTINCT FROM OLD.property_id
          OR NEW.environment_id IS DISTINCT FROM OLD.environment_id
          OR NEW.scan_id IS DISTINCT FROM OLD.scan_id
          #{fetch_url_clause}
          OR NEW.normalized_url_digest IS DISTINCT FROM OLD.normalized_url_digest
          OR NEW.normalization_version IS DISTINCT FROM OLD.normalization_version
          OR NEW.normalized_url IS DISTINCT FROM OLD.normalized_url
          OR NEW.host_digest IS DISTINCT FROM OLD.host_digest
          OR NEW.discovery_source IS DISTINCT FROM OLD.discovery_source
          OR NEW.discovered_from_id IS DISTINCT FROM OLD.discovered_from_id
          OR NEW.maximum_attempts IS DISTINCT FROM OLD.maximum_attempts
          OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
          RAISE EXCEPTION 'crawl URL identity and discovery provenance are immutable';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end
end
