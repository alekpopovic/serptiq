# frozen_string_literal: true

require "pathname"
require "psych"

module Searchops
  module Quality
    class CiWorkflowValidator
      REQUIRED_JOBS = %w[tracker quality test security system_test production_container].freeze
      ACTION_PATTERN = /^\s*uses:\s*([^#\s]+)(?:\s+#\s*(\S+))?/.freeze
      IMMUTABLE_ACTION_PATTERN = /\A[^@\s]+@[0-9a-f]{40}\z/.freeze
      VERSION_COMMENT_PATTERN = /\Av?\d+\.\d+\.\d+\z/.freeze
      POSTGRES_DIGEST_PATTERN = /\Apostgres:[^@\s]+@sha256:[0-9a-f]{64}\z/.freeze

      attr_reader :path

      def initialize(path:)
        @path = Pathname(path)
      end

      def validate
        @source = path.binread.encode(Encoding::UTF_8)
        @document = Psych.safe_load(@source, aliases: true)
        return [ "#{path}: workflow root must be a mapping" ] unless @document.is_a?(Hash)

        errors = []
        errors.concat(validate_token_permissions)
        errors.concat(validate_action_pins)
        errors.concat(validate_jobs)
        errors.concat(validate_concurrency)
        errors.concat(validate_sensitive_constructs)
        errors
      rescue Psych::Exception, EncodingError => e
        [ "#{path}: invalid workflow YAML: #{e.message.lines.first.to_s.strip}" ]
      end

      private

      attr_reader :document, :source

      def validate_token_permissions
        permissions = document["permissions"]
        return [ "top-level permissions must be exactly contents: read" ] unless permissions == { "contents" => "read" }

        errors = []
        jobs.each do |job_name, job|
          next unless job.is_a?(Hash) && job.key?("permissions")

          values = job.fetch("permissions")
          safe = values.is_a?(Hash) && values.values.all? { |value| %w[read none].include?(value) }
          errors << "job #{job_name} grants a write-capable or malformed permission" unless safe
        end
        errors
      end

      def validate_action_pins
        errors = source.each_line.filter_map do |line|
          match = ACTION_PATTERN.match(line)
          next unless match

          action, version = match.captures
          next if action.start_with?("./")
          if !IMMUTABLE_ACTION_PATTERN.match?(action)
            "external action #{action.inspect} is not pinned to a full commit SHA"
          elsif !VERSION_COMMENT_PATTERN.match?(version.to_s)
            "external action #{action.inspect} must include an exact version comment"
          end
        end

        jobs.each do |job_name, job|
          Array(job.is_a?(Hash) ? job["steps"] : nil).each do |step|
            next unless step.is_a?(Hash) && step["uses"].to_s.start_with?("actions/checkout@")

            errors << "job #{job_name} checkout must disable credential persistence" unless step.dig("with", "persist-credentials") == false
          end
        end
        errors
      end

      def validate_jobs
        errors = []
        missing = [ *REQUIRED_JOBS, "required" ] - jobs.keys
        errors << "missing required jobs: #{missing.join(', ')}" if missing.any?

        jobs.each do |job_name, job|
          unless job.is_a?(Hash)
            errors << "job #{job_name} must be a mapping"
            next
          end
          errors << "job #{job_name} must set timeout-minutes" unless positive_integer?(job["timeout-minutes"])
        end

        required = jobs["required"]
        if required.is_a?(Hash)
          needs = Array(required["needs"])
          errors << "required job must depend on every executable job" unless needs.sort == REQUIRED_JOBS.sort
          errors << "required job must run with always()" unless required["if"].to_s == "always()"
        end

        errors.concat(validate_postgres_services)
        errors.concat(validate_artifacts)
        errors.concat(validate_expected_commands)
        errors
      end

      def validate_postgres_services
        jobs.filter_map do |job_name, job|
          next unless job.is_a?(Hash)

          postgres = job.dig("services", "postgres")
          next unless postgres
          image = postgres["image"].to_s
          "job #{job_name} must pin PostgreSQL by sha256 digest" unless POSTGRES_DIGEST_PATTERN.match?(image)
        end
      end

      def validate_artifacts
        jobs.flat_map do |job_name, job|
          Array(job.is_a?(Hash) ? job["steps"] : nil).filter_map do |step|
            next unless step.is_a?(Hash) && step["uses"].to_s.start_with?("actions/upload-artifact@")

            retention = step.dig("with", "retention-days")
            unless step["if"].to_s == "failure()" && retention.is_a?(Integer) && retention.between?(1, 7)
              "job #{job_name} artifacts must be failure-only with retention-days between 1 and 7"
            end
          end
        end
      end

      def validate_expected_commands
        requirements = {
          "tracker" => %w[prompt_tracker.rb test_prompt_tracker.rb check_adr_index],
          "quality" => [ "bin/quality" ],
          "test" => [ "bin/rails test" ],
          "security" => %w[bundler-audit brakeman],
          "system_test" => [ "bin/rails test:system" ],
          "production_container" => [ "script/ci_container_smoke" ]
        }

        requirements.flat_map do |job_name, commands|
          job_source = jobs.fetch(job_name, {}).to_s
          commands.filter_map { |command| "job #{job_name} must run #{command}" unless job_source.include?(command) }
        end
      end

      def validate_concurrency
        concurrency = document["concurrency"]
        return [ "workflow must define branch-aware concurrency" ] unless concurrency.is_a?(Hash)

        cancellation = concurrency["cancel-in-progress"].to_s
        errors = []
        group = concurrency["group"].to_s
        errors << "concurrency group must include workflow and ref" unless group.include?("github.workflow") && group.include?("github.ref")
        errors << "protected default-branch runs must not be auto-cancelled" unless cancellation.include?("github.event.repository.default_branch") && cancellation.include?("!=")
        errors
      end

      def validate_sensitive_constructs
        errors = []
        errors << "pull_request_target is forbidden" if source.match?(/^\s*pull_request_target\s*:/)
        errors << "repository secrets must not be injected into this CI workflow" if source.include?("secrets.")
        errors << "long-lived cloud access keys are forbidden" if source.match?(/AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|GOOGLE_APPLICATION_CREDENTIALS/)
        errors << "locked Bundler cache is required" unless source.include?("bundler-cache: true") && path.dirname.dirname.dirname.join("Gemfile.lock").file?
        errors
      end

      def jobs
        value = document["jobs"]
        value.is_a?(Hash) ? value : {}
      end

      def positive_integer?(value)
        value.is_a?(Integer) && value.positive?
      end
    end
  end
end
