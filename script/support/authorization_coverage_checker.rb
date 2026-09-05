# frozen_string_literal: true

require "pathname"
require "yaml"

module Searchops
  module Authorization
    class CoverageChecker
      CONTROLLER_POLICY_KINDS = %w[permission exempt filtered].freeze
      RESOURCE_SCOPES = %w[
        organization project property project_collection property_collection
      ].freeze
      SCOPED_SURFACE_CONTROLLERS = %w[
        Projects::ProjectsController
        Onboarding::ProjectSetupsController
        Properties::PropertiesController
        Properties::EnvironmentsController
        Verification::ChallengesController
        Crawling::PoliciesController
      ].freeze

      attr_reader :root, :inventory_path

      def initialize(root:, inventory_path:)
        @root = Pathname(root)
        @inventory_path = Pathname(inventory_path)
      end

      def check
        document = YAML.safe_load_file(inventory_path, aliases: true)
        issues = []
        issues << "authorization inventory version must equal 1" unless document["version"] == 1
        permissions = ::Authorization::Catalog.load.permissions.index_by(&:key)
        check_controllers(document.fetch("controllers", {}), permissions, issues)
        check_jobs(document.fetch("jobs", {}), issues)
        check_domain_operations(document.fetch("domain_operations", {}), permissions, issues)
        issues.sort.freeze
      rescue KeyError, Psych::Exception => error
        [ "authorization inventory could not be loaded: #{error.message}" ].freeze
      end

      private

      def check_controllers(inventory, permissions, issues)
        expected_sources = inventory.values.map { |entry| entry.fetch("source") }.sort
        actual_sources = Dir[root.join("app/controllers/tenancy/*_controller.rb")].map do |path|
          Pathname(path).relative_path_from(root).to_s
        end
        actual_sources << "app/controllers/dashboard_controller.rb"
        (actual_sources.sort - expected_sources).each do |source|
          issues << "#{source}: tenant controller is missing from authorization inventory"
        end

        inventory.each do |class_name, entry|
          controller = class_name.constantize
          actual_actions = controller.public_instance_methods(false).map(&:to_s).sort
          configured_actions = entry.fetch("actions").keys.sort
          (actual_actions - configured_actions).each do |action|
            issues << "#{class_name}##{action}: public action is missing from authorization inventory"
          end
          (configured_actions - actual_actions).each do |action|
            issues << "#{class_name}##{action}: inventory action does not exist"
          end
          entry.fetch("actions").each do |action, policy|
            label = "#{class_name}##{action}"
            validate_controller_policy(policy, label, issues)
            validate_permission(policy, label, permissions, issues)
            validate_resource_scope(policy, label, permissions, issues)
            if SCOPED_SURFACE_CONTROLLERS.include?(class_name) && !policy.key?("scope")
              issues << "#{label}: scoped resource action is missing scope metadata"
            end
            validate_controller_declaration(controller, action, policy, issues)
          end
        end
      end

      def validate_controller_policy(policy, label, issues)
        kind = policy.fetch("kind")
        issues << "#{label}: unsupported controller policy kind #{kind}" unless
          CONTROLLER_POLICY_KINDS.include?(kind)
        return unless kind == "filtered"

        issues << "#{label}: filtered collection requires a reason" if policy["reason"].to_s.empty?
        unless %w[project_collection property_collection].include?(policy["scope"])
          issues << "#{label}: filtered collection has incompatible scope #{policy['scope']}"
        end
      end

      def validate_controller_declaration(controller, action, policy, issues)
        declarations = controller.authorization_declarations.fetch(action.to_s, [])
        expected_kind = policy.fetch("kind") == "permission" ? "required" : "exempt"
        expected_permission = if expected_kind == "required"
          policy.fetch("permission")
        else
          "exempt:#{policy['reason']}"
        end
        return if declarations.any? do |declaration|
          declaration.fetch(:kind) == expected_kind && declaration.fetch(:permission) == expected_permission
        end

        issues << "#{controller.name}##{action}: missing #{expected_kind} declaration for #{expected_permission}"
      end

      def check_jobs(inventory, issues)
        expected_classes = inventory.keys.sort
        actual_classes = Dir[root.join("app/jobs/**/*_job.rb")].filter_map do |path|
          next if path.end_with?("application_job.rb")

          Pathname(path).relative_path_from(root.join("app/jobs")).sub_ext("").each_filename
            .map { |part| part.camelize }.join("::")
        end.sort
        (actual_classes - expected_classes).each do |class_name|
          issues << "#{class_name}: job is missing from authorization inventory"
        end

        inventory.each do |class_name, expected|
          actual = class_name.constantize.authorization_job_policy
          unless actual && actual.fetch(:kind) == expected.fetch("kind") &&
              actual.fetch(:name, nil) == expected["name"]
            issues << "#{class_name}: authorization job policy does not match inventory"
          end
        end
      end

      def check_domain_operations(inventory, permissions, issues)
        inventory.each do |operation, policy|
          validate_permission(policy, operation, permissions, issues)
          validate_resource_scope(policy, operation, permissions, issues)
        end
      end

      def validate_permission(policy, label, permissions, issues)
        return unless %w[permission filtered].include?(policy.fetch("kind"))
        return if permissions.key?(policy.fetch("permission"))

        issues << "#{label}: unknown permission #{policy.fetch('permission')}"
      end

      def validate_resource_scope(policy, label, permissions, issues)
        scope = policy["scope"]
        return unless scope

        unless RESOURCE_SCOPES.include?(scope)
          issues << "#{label}: unknown authorization scope #{scope}"
          return
        end
        permission = permissions[policy["permission"]]
        return unless permission

        compatible = if permission.scope == "organization"
          scope == "organization"
        else
          scope != "organization"
        end
        issues << "#{label}: #{permission.key} is incompatible with #{scope} scope" unless compatible
      end
    end
  end
end
