# frozen_string_literal: true

require "bigdecimal"
require "digest"
require "json"
require "pathname"
require "time"
require "yaml"

module Usage
  class Catalog
    DEFAULT_PATH = Rails.root.join("config_blueprints/usage_meters.yml")
    EXPECTED_VERSION = 1
    EXPECTED_KEYS = %w[
      crawl.http_fetch crawl.rendered_page performance.lighthouse_page
      app_listing.locale_snapshot deep_link.validation url_inspection.import reports.generated
    ].freeze
    ROOT_KEYS = %w[version meters].freeze
    METER_KEYS = %w[
      key name unit billing_unit pool_key quota_entitlement_key window_policy description rates
    ].freeze
    RATE_KEYS = %w[version weight effective_at].freeze
    KEY_PATTERN = /\A[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+\z/
    UNIT_PATTERN = /\A[a-z][a-z0-9_]{1,31}\z/
    WINDOW_POLICIES = %w[utc_calendar_month provider_billing_period].freeze

    attr_reader :meters, :checksum

    def self.load(path: DEFAULT_PATH)
      new(path: path).tap(&:validate!)
    end

    def initialize(path:)
      contents = Pathname(path).binread
      @checksum = Digest::SHA256.hexdigest(contents)
      @document = YAML.safe_load(contents, permitted_classes: [], permitted_symbols: [], aliases: false)
      @meters = parse_meters.freeze
    rescue Errno::ENOENT, Psych::Exception, EncodingError => error
      raise CatalogInvalid.new(issues: [ "catalog could not be loaded: #{error.class}" ]), cause: nil
    end

    def validate!
      issues = []
      issues << "catalog root must contain exactly the governed keys" unless
        @document.is_a?(Hash) && @document.keys.sort == ROOT_KEYS.sort
      issues << "version must equal #{EXPECTED_VERSION}" unless @document.is_a?(Hash) &&
        @document["version"] == EXPECTED_VERSION
      issues << "meter keys must match the governed catalog" unless meters.map(&:key) == EXPECTED_KEYS
      validate_meters(issues)
      validate_entitlement_keys(issues)
      validate_plan_weights(issues)
      raise CatalogInvalid.new(issues: issues) if issues.any?

      self
    end

    private

    def parse_meters
      Array(@document.is_a?(Hash) ? @document["meters"] : nil).map do |raw|
        row = raw.is_a?(Hash) ? raw : {}
        definition = {
          key: row["key"], name: row["name"], unit: row["unit"], billing_unit: row["billing_unit"],
          pool_key: row["pool_key"], quota_entitlement_key: row["quota_entitlement_key"],
          window_policy: row["window_policy"], description: row["description"]
        }
        rates = Array(row["rates"]).map { |rate| parse_rate(rate) }
        MeterSpec.new(
          **definition, rates: rates,
          catalog_checksum: Digest::SHA256.hexdigest(JSON.generate(definition))
        )
      end
    end

    def parse_rate(raw)
      row = raw.is_a?(Hash) ? raw : {}
      version = row["version"]
      weight = strict_decimal(row["weight"])
      effective_at = Time.iso8601(row["effective_at"].to_s)
      attributes = { version: version, weight: weight.to_s("F"), effective_at: effective_at.utc.iso8601(6) }
      RateSpec.new(
        version: version, weight: weight, effective_at: effective_at,
        catalog_checksum: Digest::SHA256.hexdigest(JSON.generate(attributes))
      )
    rescue ArgumentError
      RateSpec.new(version: version, weight: nil, effective_at: nil, catalog_checksum: "invalid")
    end

    def validate_meters(issues)
      raw_meters = Array(@document.is_a?(Hash) ? @document["meters"] : nil)
      issues << "meter keys must be unique" unless meters.map(&:key).uniq.length == meters.length
      meters.each_with_index do |meter, index|
        raw = raw_meters[index]
        prefix = "meter #{meter.key.presence || index + 1}"
        issues << "#{prefix} contains unknown or missing fields" unless
          raw.is_a?(Hash) && raw.keys.sort == METER_KEYS.sort
        issues << "#{prefix} has an invalid key or pool" unless
          KEY_PATTERN.match?(meter.key) && KEY_PATTERN.match?(meter.pool_key)
        issues << "#{prefix} has invalid units" unless
          UNIT_PATTERN.match?(meter.unit) && UNIT_PATTERN.match?(meter.billing_unit)
        issues << "#{prefix} has an invalid quota entitlement" unless
          meter.quota_entitlement_key.nil? || entitlement_key?(meter.quota_entitlement_key)
        issues << "#{prefix} has an invalid window policy" unless WINDOW_POLICIES.include?(meter.window_policy)
        issues << "#{prefix} has invalid text" unless
          bounded_text?(meter.name, 100) && bounded_text?(meter.description, 240)
        validate_rates(meter, raw, issues, prefix)
      end
    end

    def validate_rates(meter, raw, issues, prefix)
      raw_rates = Array(raw.is_a?(Hash) ? raw["rates"] : nil)
      valid = meter.rates.any? && meter.rates.each_with_index.all? do |rate, index|
        source = raw_rates[index]
        source.is_a?(Hash) && source.keys.sort == RATE_KEYS.sort &&
          rate.version.is_a?(Integer) && rate.version.positive? && rate.weight.is_a?(BigDecimal) &&
          rate.weight.positive? && decimal_scale(rate.weight) <= 6 && rate.effective_at.is_a?(Time) &&
          rate.catalog_checksum.match?(/\A[0-9a-f]{64}\z/)
      end
      versions = meter.rates.map(&:version)
      instants = meter.rates.map(&:effective_at)
      ordered = meter.rates.each_cons(2).all? do |left, right|
        right.version == left.version + 1 && right.effective_at > left.effective_at
      end
      issues << "#{prefix} has invalid effective rates" unless
        valid && versions.uniq.length == versions.length && instants.compact.uniq.length == instants.length && ordered
    end

    def validate_plan_weights(issues)
      weights = Plans::Public.validate_catalog.credit_weights
      meters.first(6).each do |meter|
        expected = weights[meter.key]
        actual = meter.rates.first&.weight
        issues << "meter #{meter.key} weight differs from plans.yml" unless actual == BigDecimal(expected.to_s)
      end
    rescue Shared::Public::ValidationError
      issues << "plan catalog weights could not be validated"
    end

    def validate_entitlement_keys(issues)
      keys = Entitlements::Public.validate_catalog.definitions.map(&:key)
      meters.each do |meter|
        next if meter.quota_entitlement_key.nil? || keys.include?(meter.quota_entitlement_key)

        issues << "meter #{meter.key} refers to an unknown quota entitlement"
      end
    rescue Shared::Public::ValidationError
      issues << "entitlement catalog could not be validated"
    end

    def strict_decimal(value)
      raise ArgumentError unless value.is_a?(Integer) || value.is_a?(BigDecimal)

      BigDecimal(value.to_s)
    end

    def decimal_scale(value)
      [ value.frac.to_s("F").delete_prefix("0.").sub(/0+\z/, "").length, 0 ].max
    end

    def entitlement_key?(value)
      KEY_PATTERN.match?(value)
    end

    def bounded_text?(value, maximum)
      value.is_a?(String) && value == value.strip && value.length.between?(3, maximum)
    end
  end
end
