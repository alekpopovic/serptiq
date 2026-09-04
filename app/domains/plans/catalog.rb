# frozen_string_literal: true

require "digest"
require "date"
require "json"
require "pathname"
require "yaml"

module Plans
  class Catalog
    DEFAULT_PATH = Rails.root.join("config_blueprints/plans.yml")
    SOURCE_PATH = "config_blueprints/plans.yml"
    EXPECTED_SCHEMA_VERSION = 1
    EXPECTED_PLAN_KEYS = Plan::KEYS
    EXPECTED_ENTITLEMENT_COUNT = 47
    EXPECTED_CREDIT_WEIGHT_KEYS = %w[
      crawl.http_fetch crawl.rendered_page performance.lighthouse_page
      app_listing.locale_snapshot deep_link.validation url_inspection.import
    ].freeze
    PLAN_KEYS = %w[key display_name version monthly_price_eur annual_price_eur positioning entitlements].freeze
    ROOT_KEYS = %w[schema_version generated_for credit_weights plans].freeze
    KEY_PATTERN = /\A[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+\z/

    attr_reader :schema_version, :definitions, :credit_weights, :checksum

    def self.load(path: DEFAULT_PATH)
      new(path: path).tap(&:validate!)
    end

    def initialize(path: DEFAULT_PATH)
      contents = Pathname(path).binread
      @checksum = Digest::SHA256.hexdigest(contents)
      @document = YAML.safe_load(contents, permitted_classes: [ Date ], permitted_symbols: [], aliases: false)
      parse
    rescue Errno::ENOENT, Psych::Exception, EncodingError => error
      raise CatalogInvalid.new(issues: [ "catalog could not be loaded: #{error.class}" ]), cause: nil
    end

    def validate!
      issues = []
      issues << "catalog root must contain exactly the governed keys" unless @document.is_a?(Hash) &&
        @document.keys.sort == ROOT_KEYS.sort
      issues << "schema_version must equal #{EXPECTED_SCHEMA_VERSION}" unless schema_version == EXPECTED_SCHEMA_VERSION
      issues << "generated_for must be an ISO 8601 date" unless valid_generated_for?
      issues << "plan keys must be #{EXPECTED_PLAN_KEYS.join(', ')}" unless definitions.map(&:key) == EXPECTED_PLAN_KEYS
      validate_credit_weights(issues)
      validate_definitions(issues)
      raise CatalogInvalid.new(issues: issues) if issues.any?

      self
    end

    private

    def parse
      raise CatalogInvalid.new(issues: [ "catalog root must be a mapping" ]) unless @document.is_a?(Hash)

      @schema_version = @document["schema_version"]
      @credit_weights = @document.fetch("credit_weights", {}).to_h.freeze
      @definitions = Array(@document["plans"]).each_with_index.map do |raw, index|
        row = raw.is_a?(Hash) ? raw : {}
        pricing_kind = custom_price?(row) ? "custom" : "fixed"
        attributes = {
          key: row["key"],
          display_name: row["display_name"],
          version: row["version"],
          positioning: row["positioning"],
          currency: "EUR",
          pricing_kind: pricing_kind,
          monthly_price_cents: price_cents(row["monthly_price_eur"]),
          annual_price_cents: price_cents(row["annual_price_eur"]),
          entitlements: row["entitlements"].is_a?(Hash) ? row["entitlements"] : {},
          display_order: index + 1
        }
        CatalogDefinition.new(**attributes, checksum: definition_checksum(attributes))
      end.freeze
    end

    def custom_price?(row)
      row["monthly_price_eur"] == "custom" || row["annual_price_eur"] == "custom"
    end

    def price_cents(value)
      value.is_a?(Integer) ? value * 100 : nil
    end

    def definition_checksum(attributes)
      Digest::SHA256.hexdigest(JSON.generate(attributes.except(:display_order)))
    end

    def validate_credit_weights(issues)
      unless credit_weights.keys == EXPECTED_CREDIT_WEIGHT_KEYS &&
          credit_weights.all? { |key, value| KEY_PATTERN.match?(key.to_s) && value.is_a?(Integer) && value.positive? }
        issues << "credit weights must be positive integers with stable keys"
      end
    end

    def validate_definitions(issues)
      versions = []
      entitlement_keys = definitions.first&.entitlements&.keys || []
      definitions.each_with_index do |definition, index|
        row = Array(@document["plans"])[index]
        issues << "plan #{definition.key || index + 1} contains unknown fields" unless
          row.is_a?(Hash) && (row.keys - PLAN_KEYS).empty?
        issues << "plan #{definition.key || index + 1} has invalid version" unless
          definition.version.is_a?(Integer) && definition.version.positive?
        issues << "plan #{definition.key || index + 1} has invalid display name" unless
          bounded_text?(definition.display_name, 80)
        issues << "plan #{definition.key || index + 1} has invalid positioning" unless
          bounded_text?(definition.positioning, 240)
        issues << "plan #{definition.key || index + 1} has incomplete entitlements" unless
          definition.entitlements.length == EXPECTED_ENTITLEMENT_COUNT && definition.entitlements.keys == entitlement_keys
        issues << "plan #{definition.key || index + 1} has invalid entitlement values" unless
          valid_entitlements?(definition.entitlements)
        issues << "plan #{definition.key || index + 1} has invalid pricing" unless valid_pricing?(definition)
        versions << [ definition.key, definition.version ]
      end
      issues << "plan key/version pairs must be unique" unless versions.uniq.length == versions.length
    end

    def valid_pricing?(definition)
      if definition.pricing_kind == "custom"
        definition.key == "enterprise" && definition.monthly_price_cents.nil? && definition.annual_price_cents.nil?
      else
        [ definition.monthly_price_cents, definition.annual_price_cents ].all? { |value| value.is_a?(Integer) && value >= 0 }
      end
    end

    def bounded_text?(value, maximum)
      value.is_a?(String) && value == value.strip && value.length.between?(1, maximum)
    end

    def valid_generated_for?
      value = @document["generated_for"]
      value.is_a?(String) && Date.iso8601(value).iso8601 == value
    rescue Date::Error
      false
    end

    def valid_entitlements?(entitlements)
      entitlements.all? do |key, value|
        valid_value = case value
        when true, false, Integer then true
        when String then value.length.between?(1, 64) && value == value.strip
        else false
        end
        KEY_PATTERN.match?(key.to_s) && valid_value
      end
    end
  end
end
