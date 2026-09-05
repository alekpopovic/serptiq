# frozen_string_literal: true

require "pathname"

module Searchops
  module Architecture
    class AccessBoundaryChecker
      Violation = Data.define(:path, :line, :reason) do
        def to_s
          "#{path}:#{line}: #{reason}"
        end
      end

      FEATURE_MODULES = %w[
        projects properties verification crawling analysis findings issues app_discovery
        integrations search_data releases reporting notifications
      ].freeze
      COMMERCIAL_PLAN_KEYS = %w[free starter growth agency enterprise].freeze
      PLAN_COMPARISON = /\bplan(?:_key|\.key|\.name)?\s*(?:==|!=|===)\s*["'](?:#{COMMERCIAL_PLAN_KEYS.join('|')})["']/i
      REVERSED_PLAN_COMPARISON = /["'](?:#{COMMERCIAL_PLAN_KEYS.join('|')})["']\s*(?:==|!=|===)\s*\bplan/i
      DIRECT_QUOTA_CALL = /\bUsage::Public\.(?:reserve|extend_reservation|finalize_reservation|release_reservation)\b/
      DIRECT_QUOTA_MODEL_MUTATION = /\bUsage::(?:QuotaReservation|ReservationOperation|UsageEvent)\.(?:create!?|insert!?|upsert!?|update(?:_all|!)?|delete(?:_all)?|destroy(?:_all|!)?)\b/
      PROVIDER_SPECIFIC_ACCESS = /\b(?:LemonSqueezy|lemon_squeezy|provider_variant_id)\b/
      DIRECT_NETWORK_CLIENT = /(?:\bNet::HTTP\b|\bTCPSocket\b|\bSocket\.tcp\b|\bURI\.open\b|\bOpenURI\b|\bFaraday\b|\bHTTPX\b|\bHTTParty\b)/
      AUTHORIZED_QUOTA_CALLERS = %w[
        app/domains/authorization/access_boundary.rb
        app/domains/usage/public.rb
      ].freeze
      AUTHORIZED_NETWORK_CLIENTS = %w[
        app/adapters/billing/lemon_squeezy/net_http_transport.rb
        app/adapters/identity/net_http_transport.rb
        app/adapters/shared/network_safety/net_http_transport.rb
      ].freeze

      def initialize(root:)
        @root = Pathname(root).expand_path
      end

      def check
        (plan_name_violations + quota_violations + provider_access_violations + network_client_violations)
          .sort_by { |violation| [ violation.path, violation.line ] }
      end

      private

      def plan_name_violations
        feature_files.flat_map do |path|
          line_violations(path, [ PLAN_COMPARISON, REVERSED_PLAN_COMPARISON ],
            "feature access must use entitlement keys, never commercial plan-name checks")
        end
      end

      def quota_violations
        application_files.flat_map do |path|
          relative_path = relative(path)
          next [] if AUTHORIZED_QUOTA_CALLERS.include?(relative_path) ||
            relative_path.start_with?("app/domains/usage/")

          line_violations(path, [ DIRECT_QUOTA_CALL, DIRECT_QUOTA_MODEL_MUTATION ],
            "quota mutations must go through Authorization::Public.with_access or the Usage owner")
        end
      end

      def provider_access_violations
        @root.join("app/domains/authorization").glob("**/*.rb").flat_map do |path|
          line_violations(path, [ PROVIDER_SPECIFIC_ACCESS ],
            "core access code must not reference provider classes or provider variant identifiers")
        end
      end

      def network_client_violations
        application_files.flat_map do |path|
          next [] if AUTHORIZED_NETWORK_CLIENTS.include?(relative(path))

          line_violations(
            path,
            [ DIRECT_NETWORK_CLIENT ],
            "outbound HTTP clients are restricted to approved provider adapters or Shared network safety"
          )
        end
      end

      def line_violations(path, patterns, reason)
        path.each_line.with_index(1).filter_map do |line, number|
          Violation.new(relative(path), number, reason) if patterns.any? { |pattern| pattern.match?(line) }
        end
      end

      def feature_files
        FEATURE_MODULES.flat_map do |name|
          @root.join("app/domains", name).glob("**/*.rb")
        end
      end

      def application_files
        @root.join("app").glob("**/*.rb")
      end

      def relative(path)
        path.relative_path_from(@root).to_s
      end
    end
  end
end
