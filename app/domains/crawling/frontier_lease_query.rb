# frozen_string_literal: true

module Crawling
  class FrontierLeaseQuery
    ACTIVE_SCAN_STATUSES = %w[queued running].freeze

    def initialize(connection: ActiveRecord::Base.connection)
      @connection = connection
    end

    def lease(worker_id:, limit:, leased_at:, lease_expires_at:)
      @connection.exec_query(sql(
        worker_id: worker_id,
        limit: limit,
        leased_at: leased_at,
        lease_expires_at: lease_expires_at
      )).map { |row| lease_from(row) }
    end

    def explain(limit:, at:)
      statement = sql(
        worker_id: "explain-worker",
        limit: limit,
        leased_at: at,
        lease_expires_at: at + 2.minutes
      )
      @connection.select_value("EXPLAIN (FORMAT JSON, COSTS TRUE) #{statement}")
    end

    private

    def sql(worker_id:, limit:, leased_at:, lease_expires_at:)
      <<~SQL.squish
        WITH eligible AS MATERIALIZED (
          SELECT crawl_urls.id, crawl_urls.organization_id, crawl_urls.scan_id,
            crawl_urls.host_digest, crawl_urls.priority, crawl_urls.depth,
            row_number() OVER (
              PARTITION BY crawl_urls.organization_id, crawl_urls.host_digest
              ORDER BY crawl_urls.priority DESC, crawl_urls.depth, crawl_urls.id
            ) AS host_round,
            row_number() OVER (
              PARTITION BY crawl_urls.organization_id, crawl_urls.scan_id
              ORDER BY crawl_urls.priority DESC, crawl_urls.depth, crawl_urls.id
            ) AS scan_round
          FROM crawl_urls
          INNER JOIN scans ON scans.id = crawl_urls.scan_id
            AND scans.organization_id = crawl_urls.organization_id
          WHERE crawl_urls.state = 'pending'
            AND crawl_urls.next_attempt_at <= #{@connection.quote(leased_at)}
            AND scans.status IN (#{quote_list(ACTIVE_SCAN_STATUSES)})
        ), ranked AS MATERIALIZED (
          SELECT eligible.*,
            row_number() OVER (
              PARTITION BY eligible.organization_id
              ORDER BY eligible.host_round, eligible.scan_round,
                eligible.priority DESC, eligible.depth, eligible.id
            ) AS organization_round
          FROM eligible
        ), candidates AS MATERIALIZED (
          SELECT crawl_urls.id
          FROM crawl_urls
          INNER JOIN ranked ON ranked.id = crawl_urls.id
          ORDER BY ranked.organization_round, ranked.host_round, ranked.scan_round,
            ranked.priority DESC, ranked.depth, ranked.id
          LIMIT #{Integer(limit)}
          FOR UPDATE OF crawl_urls SKIP LOCKED
        ), tokens AS MATERIALIZED (
          SELECT candidates.id, encode(gen_random_bytes(32), 'hex') AS token
          FROM candidates
        )
        UPDATE crawl_urls
        SET state = 'leased', leased_by = #{@connection.quote(worker_id)},
          lease_token_digest = encode(digest(tokens.token, 'sha256'), 'hex'),
          leased_at = #{@connection.quote(leased_at)},
          lease_expires_at = #{@connection.quote(lease_expires_at)},
          next_attempt_at = NULL, attempts = crawl_urls.attempts + 1,
          updated_at = #{@connection.quote(leased_at)}
        FROM tokens
        WHERE crawl_urls.id = tokens.id
        RETURNING crawl_urls.*, tokens.token AS raw_lease_token
      SQL
    end

    def quote_list(values)
      values.map { |value| @connection.quote(value) }.join(", ")
    end

    def lease_from(row)
      FrontierLease.new(
        id: row.fetch("id"),
        organization_id: row.fetch("organization_id"),
        project_id: row.fetch("project_id"),
        property_id: row.fetch("property_id"),
        environment_id: row.fetch("environment_id"),
        scan_id: row.fetch("scan_id"),
        fetch_url: row.fetch("fetch_url"),
        normalized_url: row.fetch("normalized_url"),
        normalized_url_digest: row.fetch("normalized_url_digest"),
        normalization_version: row.fetch("normalization_version"),
        host_digest: row.fetch("host_digest"),
        depth: row.fetch("depth"),
        priority: row.fetch("priority"),
        attempts: row.fetch("attempts"),
        maximum_attempts: row.fetch("maximum_attempts"),
        worker_id: row.fetch("leased_by"),
        token: row.fetch("raw_lease_token"),
        expires_at: row.fetch("lease_expires_at")
      )
    end
  end
end
