# frozen_string_literal: true

module Searchops
  class DatabaseConfigurationValidator
    REQUIRED_CONNECTIONS = %w[primary queue cache cable].freeze

    def initialize(environment:, configurations: ActiveRecord::Base.configurations)
      @environment = environment.to_s
      @configurations = configurations.configs_for(env_name: @environment)
    end

    def validate!
      errors = []
      by_name = @configurations.to_h { |configuration| [ configuration.name, configuration ] }
      missing = REQUIRED_CONNECTIONS - by_name.keys
      errors << "missing database connections: #{missing.join(', ')}" unless missing.empty?

      by_name.each do |name, configuration|
        errors << "database #{name} must use PostgreSQL" unless configuration.adapter == "postgresql"
        validate_application_name(name, configuration, errors)
      end

      return true if errors.empty?

      raise Configuration::Error, "Invalid SearchOps database configuration (#{@environment}): #{errors.join('; ')}"
    end

    private

    def validate_application_name(name, configuration, errors)
      application_name = configuration.configuration_hash[:application_name].to_s
      if application_name.empty?
        errors << "database #{name} is missing application_name"
      elsif application_name.bytesize > 63
        errors << "database #{name} application_name exceeds PostgreSQL's 63-byte limit"
      end
    end
  end
end
