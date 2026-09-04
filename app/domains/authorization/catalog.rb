# frozen_string_literal: true

require "digest"
require "pathname"
require "yaml"

module Authorization
  class Catalog
    DEFAULT_PATH = Rails.root.join("config_blueprints/permissions.yml")
    SOURCE_PATH = "config_blueprints/permissions.yml"
    EXPECTED_SCHEMA_VERSION = 1
    EXPECTED_PERMISSION_COUNT = 57
    EXPECTED_ROLES = {
      "owner" => "Owner",
      "organization_admin" => "Organization Admin",
      "billing_admin" => "Billing Admin",
      "seo_lead" => "SEO Lead",
      "developer" => "Developer",
      "content_editor" => "Content Editor",
      "analyst" => "Analyst",
      "viewer" => "Viewer"
    }.freeze
    ROLE_SCOPES = %w[organization project].freeze

    PermissionDefinition = Data.define(:key, :category, :description, :risk_level, :scope)
    RoleDefinition = Data.define(:key, :name, :assignable_scopes, :permission_keys)

    attr_reader :schema_version, :permissions, :roles, :checksum

    def self.load(path: DEFAULT_PATH)
      new(path: path).tap(&:validate!)
    end

    def initialize(path: DEFAULT_PATH)
      @path = Pathname(path)
      @contents = @path.binread
      @checksum = Digest::SHA256.hexdigest(@contents)
      @document = YAML.safe_load(@contents, permitted_classes: [], permitted_symbols: [], aliases: false)
      parse
    rescue Errno::ENOENT, Psych::Exception, EncodingError => error
      raise CatalogInvalid.new(issues: [ "catalog could not be loaded: #{error.class}" ]), cause: nil
    end

    def validate!
      issues = []
      issues << "schema_version must equal #{EXPECTED_SCHEMA_VERSION}" unless schema_version == EXPECTED_SCHEMA_VERSION
      issues << "catalog must define exactly #{EXPECTED_PERMISSION_COUNT} permissions" unless
        permissions.length == EXPECTED_PERMISSION_COUNT
      validate_permissions(issues)
      validate_roles(issues)
      raise CatalogInvalid.new(issues: issues) if issues.any?

      self
    end

    private

    def parse
      unless @document.is_a?(Hash)
        raise CatalogInvalid.new(issues: [ "catalog root must be a mapping" ])
      end

      @schema_version = @document["schema_version"]
      @permissions = Array(@document["permissions"]).map do |row|
        row = row.is_a?(Hash) ? row : {}
        PermissionDefinition.new(
          key: row["key"],
          category: row["category"],
          description: row["description"],
          risk_level: row["risk"],
          scope: row["scope"]
        ).freeze
      end.freeze
      @roles = Array(@document["system_roles"]).map do |row|
        row = row.is_a?(Hash) ? row : {}
        RoleDefinition.new(
          key: row["key"],
          name: row["name"],
          assignable_scopes: Array(row["assignable_scopes"]).freeze,
          permission_keys: Array(row["permissions"]).freeze
        ).freeze
      end.freeze
    end

    def validate_permissions(issues)
      duplicate_values(permissions.map(&:key)).each { |key| issues << "duplicate permission key #{key.inspect}" }
      permissions.each_with_index do |permission, index|
        label = permission.key.presence || "row #{index + 1}"
        issues << "permission #{label} has invalid key" unless Permission::KEY_PATTERN.match?(permission.key.to_s)
        issues << "permission #{label} lacks category" unless bounded_text?(permission.category, 64)
        issues << "permission #{label} lacks description" unless bounded_text?(permission.description, 500)
        issues << "permission #{label} has invalid risk" unless Permission::RISK_LEVELS.include?(permission.risk_level)
        issues << "permission #{label} lacks scope" unless Permission::SCOPES.include?(permission.scope)
      end
    end

    def validate_roles(issues)
      duplicate_values(roles.map(&:key)).each { |key| issues << "duplicate system role key #{key.inspect}" }
      actual = roles.to_h { |role| [ role.key, role.name ] }
      issues << "system role keys or names do not match the governed catalog" unless actual == EXPECTED_ROLES
      permission_keys = permissions.map(&:key)
      roles.each do |role|
        label = role.key.presence || "unnamed"
        issues << "role #{label} has invalid assignable scopes" unless role.assignable_scopes.present? &&
          role.assignable_scopes.uniq == role.assignable_scopes && (role.assignable_scopes - ROLE_SCOPES).empty?
        duplicate_values(role.permission_keys).each do |key|
          issues << "role #{label} repeats permission #{key.inspect}"
        end
        unknown = role.permission_keys - permission_keys
        issues << "role #{label} has unknown permissions: #{unknown.sort.join(', ')}" if unknown.any?
      end
      owner = roles.find { |role| role.key == "owner" }
      issues << "owner must grant every catalog permission" unless owner && owner.permission_keys.sort == permission_keys.sort
    end

    def duplicate_values(values)
      values.tally.select { |_value, count| count > 1 }.keys
    end

    def bounded_text?(value, maximum)
      value.is_a?(String) && value == value.strip && value.length.between?(1, maximum)
    end
  end
end
