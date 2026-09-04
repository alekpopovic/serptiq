# frozen_string_literal: true

require "date"
require "digest"
require "json"
require "pathname"
require "yaml"

module Entitlements
  class Catalog
    DEFAULT_PATH = Rails.root.join("config_blueprints/entitlements.yml")
    DEFAULT_PLANS_PATH = Rails.root.join("config_blueprints/plans.yml")
    EXPECTED_SCHEMA_VERSION = 1
    EXPECTED_COUNT = 47
    ROOT_KEYS = %w[schema_version definitions].freeze
    DEFINITION_KEYS = %w[
      key value_type unit category minimum maximum allowed_values max_length allow_custom
      security_sensitive system_default description
    ].freeze
    KEY_PATTERN = /\A[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+\z/
    TAXONOMY_PATTERN = /\A[a-z][a-z0-9_]{1,31}\z/
    TYPES = %w[boolean integer decimal enum string].freeze

    attr_reader :definitions, :plan_definitions, :checksum

    def self.load(path: DEFAULT_PATH, plans_path: DEFAULT_PLANS_PATH)
      new(path: path, plans_path: plans_path).tap(&:validate!)
    end

    def initialize(path:, plans_path:)
      contents = Pathname(path).binread
      @checksum = Digest::SHA256.hexdigest(contents)
      @document = YAML.safe_load(contents, permitted_classes: [ Date ], permitted_symbols: [], aliases: false)
      @plan_catalog = Plans::Public.validate_catalog(path: plans_path)
      @plan_definitions = @plan_catalog.definitions
      @definitions = parse_definitions.freeze
    rescue Errno::ENOENT, Psych::Exception, EncodingError => error
      raise CatalogInvalid.new(issues: [ "catalog could not be loaded: #{error.class}" ]), cause: nil
    rescue Shared::Public::ValidationError => error
      issues = error.respond_to?(:issues) ? error.issues : [ "plan catalog is invalid" ]
      raise CatalogInvalid.new(issues: issues), cause: nil
    end

    def validate!
      issues = []
      issues << "catalog root must contain exactly the governed keys" unless
        @document.is_a?(Hash) && @document.keys.sort == ROOT_KEYS.sort
      issues << "schema_version must equal #{EXPECTED_SCHEMA_VERSION}" unless
        @document["schema_version"] == EXPECTED_SCHEMA_VERSION
      issues << "catalog must define exactly #{EXPECTED_COUNT} entitlements" unless definitions.length == EXPECTED_COUNT
      issues << "entitlement keys must be unique" unless definitions.map(&:key).uniq.length == definitions.length
      validate_definition_rows(issues)
      validate_plan_values(issues)
      raise CatalogInvalid.new(issues: issues) if issues.any?

      self
    end

    private

    def parse_definitions
      Array(@document.is_a?(Hash) ? @document["definitions"] : nil).map do |raw|
        row = raw.is_a?(Hash) ? raw : {}
        attributes = {
          key: row["key"], value_type: row["value_type"], unit: row["unit"], category: row["category"],
          minimum_value: row["minimum"], maximum_value: row["maximum"],
          allowed_values: row["allowed_values"], max_length: row["max_length"],
          allow_custom: row["allow_custom"], security_sensitive: row["security_sensitive"],
          system_default: row["system_default"], customer_description: row["description"]
        }
        DefinitionSpec.new(**attributes, catalog_checksum: definition_checksum(attributes))
      end
    end

    def validate_definition_rows(issues)
      raw_rows = Array(@document["definitions"])
      definitions.each_with_index do |definition, index|
        raw = raw_rows[index]
        prefix = "entitlement #{definition.key.presence || index + 1}"
        issues << "#{prefix} contains unknown or missing fields" unless
          raw.is_a?(Hash) && raw.keys.sort == DEFINITION_KEYS.sort
        issues << "#{prefix} has an invalid key" unless KEY_PATTERN.match?(definition.key)
        issues << "#{prefix} has an invalid type" unless TYPES.include?(definition.value_type)
        issues << "#{prefix} has invalid taxonomy" unless
          TAXONOMY_PATTERN.match?(definition.unit) && TAXONOMY_PATTERN.match?(definition.category)
        issues << "#{prefix} has invalid boolean metadata" unless
          [ true, false ].include?(raw["allow_custom"]) && [ true, false ].include?(raw["security_sensitive"])
        issues << "#{prefix} has invalid validation bounds" unless validation_shape?(definition)
        issues << "#{prefix} has invalid description" unless bounded_text?(definition.customer_description, 240)
        validate_default(definition, issues, prefix)
      end
    end

    def validate_default(definition, issues, prefix)
      normalized = TypedValue.new.normalize(
        definition: definition, raw: definition.system_default, custom_allowed: false
      )
      if definition.security_sensitive && TypedValue.new.enabled?(definition: definition, value: normalized.value)
        issues << "#{prefix} must have a fail-closed security default"
      end
    rescue OverrideInvalid
      issues << "#{prefix} has an invalid system default"
    end

    def validate_plan_values(issues)
      keys = definitions.map(&:key)
      @plan_catalog.definitions.each do |plan|
        issues << "plan #{plan.key} does not define the governed entitlement keys" unless plan.entitlements.keys == keys
        plan.entitlements.each do |key, raw|
          definition = definitions.find { |candidate| candidate.key == key }
          next unless definition

          TypedValue.new.normalize(definition: definition, raw: raw)
        rescue OverrideInvalid => error
          issues << "plan #{plan.key} entitlement #{key} is invalid: #{error.reason_code}"
        end
      end
    end

    def validation_shape?(definition)
      case definition.value_type
      when "boolean"
        definition.minimum_value.nil? && definition.maximum_value.nil? &&
          definition.allowed_values.empty? && definition.max_length.nil? && !definition.allow_custom
      when "integer", "decimal"
        numeric_bounds?(definition) && definition.allowed_values.empty? && definition.max_length.nil?
      when "enum"
        definition.minimum_value.nil? && definition.maximum_value.nil? &&
          definition.allowed_values.any? && definition.allowed_values.uniq == definition.allowed_values &&
          definition.allowed_values.all? { |value| bounded_text?(value, 64) } && definition.max_length.nil?
      when "string"
        definition.minimum_value.nil? && definition.maximum_value.nil? &&
          definition.allowed_values.empty? && definition.max_length.is_a?(Integer) &&
          definition.max_length.between?(1, 4096)
      else false
      end
    end

    def numeric_bounds?(definition)
      [ definition.minimum_value, definition.maximum_value ].all? { |value| value.is_a?(Numeric) } &&
        BigDecimal(definition.minimum_value.to_s) <= BigDecimal(definition.maximum_value.to_s)
    end

    def bounded_text?(value, maximum)
      value.is_a?(String) && value == value.strip && value.length.between?(1, maximum)
    end

    def definition_checksum(attributes)
      Digest::SHA256.hexdigest(JSON.generate(attributes))
    end
  end
end
