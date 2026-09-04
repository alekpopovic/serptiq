# frozen_string_literal: true

require "pathname"
require "yaml"

module Searchops
  module Authorization
    class CoverageChecker
      attr_reader :root, :inventory_path

      def initialize(root:, inventory_path:)
        @root = Pathname(root)
        @inventory_path = Pathname(inventory_path)
      end

      def check
        document = YAML.safe_load_file(inventory_path, aliases: true)
        issues = []
        issues << "authorization inventory version must equal 1" unless document["version"] == 1
        known_permissions = ::Authorization::Catalog.load.permissions.map(&:key)
        check_controllers(document.fetch("controllers", {}), known_permissions, issues)
        check_jobs(document.fetch("jobs", {}), issues)
        check_domain_operations(document.fetch("domain_operations", {}), known_permissions, issues)
        issues.sort.freeze
      rescue KeyError, Psych::Exception => error
        [ "authorization inventory could not be loaded: #{error.message}" ].freeze
      end

      private

      def check_controllers(inventory, known_permissions, issues)
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
            validate_permission(policy, "#{class_name}##{action}", known_permissions, issues)
            validate_controller_declaration(controller, action, policy, issues)
          end
        end
      end

      def validate_controller_declaration(controller, action, policy, issues)
        declarations = controller.authorization_declarations.fetch(action.to_s, [])
        expected_kind = policy.fetch("kind") == "permission" ? "required" : "exempt"
        expected_permission = if expected_kind == "required"
          policy.fetch("permission")
        else
          "exempt:#{policy.fetch('reason')}"
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

      def check_domain_operations(inventory, known_permissions, issues)
        inventory.each do |operation, policy|
          validate_permission(policy, operation, known_permissions, issues)
        end
      end

      def validate_permission(policy, label, known_permissions, issues)
        return unless policy.fetch("kind") == "permission"
        return if known_permissions.include?(policy.fetch("permission"))

        issues << "#{label}: unknown permission #{policy.fetch('permission')}"
      end
    end
  end
end
